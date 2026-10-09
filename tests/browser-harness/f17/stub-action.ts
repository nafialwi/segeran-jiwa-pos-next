export function useActionDialog() {
  return { confirmAction: async () => false, promptAction: async () => null };
}
