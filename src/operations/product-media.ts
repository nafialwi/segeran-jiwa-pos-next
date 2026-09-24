import { requireOnlineAction } from '../health/online-action';
import { supabase } from '../lib/supabase';

export const PRODUCT_MEDIA_BUCKET = 'product-media';

const ACCEPTED_PRODUCT_IMAGE_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);
const MAX_SOURCE_BYTES = 12 * 1024 * 1024;
const MAX_OUTPUT_BYTES = 2 * 1024 * 1024;
const MAX_IMAGE_EDGE = 1200;

type MediaRpcError = {
  code?: string;
  message?: string;
  details?: string | null;
};

function mediaRpcMissing(error: MediaRpcError | null | undefined): boolean {
  const text = [error?.code ?? '', error?.message ?? '', error?.details ?? '']
    .join(' ')
    .toLowerCase();
  return (
    error?.code === '42883' ||
    error?.code === 'PGRST202' ||
    text.includes('product_media_capability') ||
    text.includes('product_media_read_v1') ||
    text.includes('set_sale_product_image')
  );
}

function mediaFail(error: MediaRpcError | null | undefined): never {
  const text = [error?.code ?? '', error?.message ?? '', error?.details ?? '']
    .join(' ')
    .toUpperCase();

  if (text.includes('SJ_PRODUCT_MANAGE_DENIED')) {
    throw new Error(
      'Akun ini tidak memiliki izin untuk mengelola foto produk.',
    );
  }
  if (text.includes('SJ_PRODUCT_MEDIA_PATH_INVALID')) {
    throw new Error('Lokasi foto produk ditolak oleh server.');
  }
  if (text.includes('SJ_PRODUCT_NOT_FOUND')) {
    throw new Error('Produk tidak ditemukan atau sudah tidak tersedia.');
  }
  if (mediaRpcMissing(error)) {
    throw new Error('Foto produk belum aktif pada backend ini.');
  }
  throw new Error(
    error?.message || error?.code || 'Foto produk gagal diperbarui.',
  );
}

export async function fetchProductMediaCapability(): Promise<boolean> {
  const { data, error } = await supabase.rpc('product_media_capability');
  if (error) {
    if (mediaRpcMissing(error)) return false;
    mediaFail(error);
  }
  return data === true;
}

export async function fetchProductMediaIndex(): Promise<
  Record<string, string>
> {
  const { data, error } = await supabase.rpc('product_media_read_v1');
  if (error) {
    if (mediaRpcMissing(error)) return {};
    mediaFail(error);
  }

  const result: Record<string, string> = {};
  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    const productId = String(row.sale_product_id ?? '');
    const imagePath =
      row.image_path === null || row.image_path === undefined
        ? ''
        : String(row.image_path);
    if (productId && imagePath) result[productId] = imagePath;
  }
  return result;
}

export function productMediaPublicUrl(
  imagePath: string | null | undefined,
): string | null {
  if (!imagePath) return null;
  return supabase.storage.from(PRODUCT_MEDIA_BUCKET).getPublicUrl(imagePath)
    .data.publicUrl;
}

type DecodedImage = {
  source: CanvasImageSource;
  width: number;
  height: number;
  dispose: () => void;
};

async function decodeImage(file: File): Promise<DecodedImage> {
  if (typeof createImageBitmap === 'function') {
    const bitmap = await createImageBitmap(file);
    return {
      source: bitmap,
      width: bitmap.width,
      height: bitmap.height,
      dispose: () => bitmap.close(),
    };
  }

  const objectUrl = URL.createObjectURL(file);
  const image = new Image();
  try {
    await new Promise<void>((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = () => reject(new Error('Gambar tidak dapat dibaca.'));
      image.src = objectUrl;
    });
    return {
      source: image,
      width: image.naturalWidth,
      height: image.naturalHeight,
      dispose: () => URL.revokeObjectURL(objectUrl),
    };
  } catch (error) {
    URL.revokeObjectURL(objectUrl);
    throw error;
  }
}
async function canvasToBlob(
  canvas: HTMLCanvasElement,
  type: string,
  quality: number,
): Promise<Blob | null> {
  return await new Promise((resolve) => {
    canvas.toBlob(resolve, type, quality);
  });
}

export async function prepareProductImage(file: File): Promise<Blob> {
  if (!ACCEPTED_PRODUCT_IMAGE_TYPES.has(file.type)) {
    throw new Error('Gunakan foto JPG, PNG, atau WebP.');
  }
  if (file.size <= 0 || file.size > MAX_SOURCE_BYTES) {
    throw new Error('Ukuran foto sumber maksimal 12 MB.');
  }

  const decoded = await decodeImage(file);
  try {
    if (decoded.width <= 0 || decoded.height <= 0) {
      throw new Error('Ukuran gambar tidak valid.');
    }

    const scale = Math.min(
      1,
      MAX_IMAGE_EDGE / Math.max(decoded.width, decoded.height),
    );
    const width = Math.max(1, Math.round(decoded.width * scale));
    const height = Math.max(1, Math.round(decoded.height * scale));
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;

    const context = canvas.getContext('2d');
    if (!context) throw new Error('Pemrosesan gambar tidak tersedia.');

    context.drawImage(decoded.source, 0, 0, width, height);

    for (const quality of [0.82, 0.7, 0.58]) {
      const webp = await canvasToBlob(canvas, 'image/webp', quality);
      if (webp && webp.size > 0 && webp.size <= MAX_OUTPUT_BYTES) return webp;
    }

    for (const quality of [0.82, 0.68, 0.55]) {
      const jpeg = await canvasToBlob(canvas, 'image/jpeg', quality);
      if (jpeg && jpeg.size > 0 && jpeg.size <= MAX_OUTPUT_BYTES) return jpeg;
    }

    throw new Error(
      'Foto masih terlalu besar setelah dikompres. Gunakan foto yang lebih kecil.',
    );
  } finally {
    decoded.dispose();
  }
}

function extensionForBlob(blob: Blob): 'webp' | 'jpg' {
  return blob.type === 'image/webp' ? 'webp' : 'jpg';
}

async function setProductImagePointer(
  productId: string,
  imagePath: string | null,
) {
  const { data, error } = await supabase.rpc('set_sale_product_image', {
    p_product_id: productId,
    p_image_path: imagePath,
    p_idempotency_key: crypto.randomUUID(),
  });
  if (error) mediaFail(error);
  return data as {
    success: boolean;
    replay: boolean;
    product_id: string;
    image_path: string | null;
    previous_image_path: string | null;
  };
}

async function removeStorageObject(path: string) {
  const { error } = await supabase.storage
    .from(PRODUCT_MEDIA_BUCKET)
    .remove([path]);
  if (error) {
    throw new Error(error.message || 'Pembersihan foto lama gagal.');
  }
}

export async function uploadProductImage(args: {
  businessId: string;
  productId: string;
  file: File;
  previousPath?: string | null;
}): Promise<{ path: string; publicUrl: string; size: number }> {
  requireOnlineAction('Unggah Foto Produk');

  if (!args.businessId || !args.productId) {
    throw new Error('Simpan produk terlebih dahulu sebelum menambahkan foto.');
  }

  const blob = await prepareProductImage(args.file);
  const extension = extensionForBlob(blob);
  const path = `${args.businessId}/${args.productId}/${crypto.randomUUID()}.${extension}`;

  const { error: uploadError } = await supabase.storage
    .from(PRODUCT_MEDIA_BUCKET)
    .upload(path, blob, {
      cacheControl: '31536000',
      contentType: blob.type,
      upsert: false,
    });

  if (uploadError) {
    throw new Error(
      uploadError.message || 'Foto produk gagal diunggah ke penyimpanan.',
    );
  }

  try {
    await setProductImagePointer(args.productId, path);
  } catch (error) {
    await removeStorageObject(path).catch(() => undefined);
    throw error;
  }

  if (args.previousPath && args.previousPath !== path) {
    await removeStorageObject(args.previousPath).catch(() => undefined);
  }

  const publicUrl = productMediaPublicUrl(path);
  if (!publicUrl) throw new Error('URL foto produk tidak tersedia.');

  return { path, publicUrl, size: blob.size };
}
export async function removeProductImage(args: {
  productId: string;
  imagePath: string;
}): Promise<void> {
  requireOnlineAction('Hapus Foto Produk');
  if (!args.productId || !args.imagePath) return;

  await setProductImagePointer(args.productId, null);
  await removeStorageObject(args.imagePath).catch(() => undefined);
}
