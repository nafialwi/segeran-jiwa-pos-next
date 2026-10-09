export async function recordInventoryCount(): Promise<never> {
  throw new Error('Fixture visual: pencatatan stok dinonaktifkan');
}
export async function postInventoryCount(): Promise<never> {
  throw new Error('Fixture visual: posting stok dinonaktifkan');
}
