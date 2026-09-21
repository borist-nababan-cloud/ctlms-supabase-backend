# Backend Development Rules

## 🚨 CRITICAL: Database Reset Prohibition

**DILARANG KERAS** menjalankan perintah berikut tanpa konfirmasi eksplisit dari user:

```bash
# PERINTAH YANG DILARANG TANPA IZIN:
npx supabase db reset
supabase db reset
npx supabase db wipe
supabase db wipe
```

### Aturan:
1. **JANGAN PERNAH** menjalankan `db reset` atau perintah apapun yang akan menghapus/mereset seluruh database (lokal maupun production) tanpa mendapat konfirmasi tertulis langsung dari user dalam percakapan yang sama.
2. Jika Anda merasa perlu menjalankan reset, **BERHENTI** dan **TANYAKAN dulu** kepada user secara eksplisit dengan menyebutkan konsekuensinya.
3. Perintah yang **AMAN** dan boleh dijalankan tanpa konfirmasi khusus:
   - `npx supabase db diff` → hanya membandingkan skema
   - `npx supabase db push` → menerapkan migrasi baru
   - `npx supabase db pull` → menarik skema dari remote
   - `npx supabase migration new <name>` → membuat file migrasi baru

### Alasan:
Proyek ini memiliki **88 migrasi** yang merepresentasikan seluruh riwayat schema production. `db reset` akan menghapus semua data dan tidak dapat dikembalikan tanpa backup penuh.
