$baseUrl = "http://localhost:3000/auth/register"

$users = @(
    @{ name = "Super Admin"; email = "superadmin@apotek.com"; password = "admin123"; role = "SUPER_ADMIN" },
    @{ name = "Admin Apotek"; email = "admin@apotek.com"; password = "admin123"; role = "ADMIN" },
    @{ name = "Kasir Utama"; email = "kasir@apotek.com"; password = "kasir123"; role = "KASIR" },
    @{ name = "Apoteker Jaga"; email = "apoteker@apotek.com"; password = "apoteker123"; role = "APOTEKER" },
    @{ name = "Pasien Umum"; email = "pasien@apotek.com"; password = "pasien123"; role = "PASIEN" }
)

Write-Host "Membangunkan server di Render (bisa makan waktu ~50 detik)..."
try {
    Invoke-RestMethod -Uri "https://apotek-backend.onrender.com" -Method Get -ErrorAction SilentlyContinue
} catch {}

foreach ($user in $users) {
    $body = $user | ConvertTo-Json
    Write-Host "Mendaftarkan $($user.email)..."
    
    try {
        $response = Invoke-RestMethod -Uri $baseUrl -Method Post -Body $body -ContentType "application/json"
        Write-Host "✅ Sukses: $($user.role)"
    } catch {
        Write-Host "❌ Gagal mendaftarkan $($user.email): $($_.Exception.Message)"
    }
}
Write-Host "Selesai!"
