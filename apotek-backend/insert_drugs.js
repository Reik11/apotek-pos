const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding Kaggle drugs into database...');

  const drugsData = [
    {
      name: 'Azitoma',
      genericName: 'Azithromycin',
      activeIngredient: 'Azithromycin 500mg',
      category: 'KERAS',
      type: 'PATEN',
      unit: 'tablet',
      sellPrice: 25000,
      buyPrice: 18000,
      requiresPrescription: true,
      description: 'Antibiotik makrolida spektrum luas untuk menghentikan pertumbuhan bakteri.',
      fdaIndications: 'Infeksi saluran pernapasan (bronkitis, pneumonia), infeksi kulit, infeksi telinga (otitis media), dan penyakit menular seksual.',
      fdaDosage: '1 tablet (500mg) sehari sekali, dihabiskan selama 3 hari berturut-turut.',
      fdaSideEffects: 'Mual, diare ringan, muntah, sakit perut, sakit kepala.',
      fdaWarnings: 'Wajib dihabiskan sesuai dosis instruksi dokter demi mencegah resistensi bakteri. Hanya untuk infeksi bakteri, tidak efektif untuk flu/virus.'
    },
    {
      name: 'Novidat',
      genericName: 'Ciprofloxacin',
      activeIngredient: 'Ciprofloxacin 500mg',
      category: 'KERAS',
      type: 'PATEN',
      unit: 'tablet',
      sellPrice: 22000,
      buyPrice: 15000,
      requiresPrescription: true,
      description: 'Antibiotik fluoroquinolone untuk infeksi bakteri berat.',
      fdaIndications: 'Infeksi saluran kemih (ISK), infeksi pernapasan bawah, infeksi kulit, sinusitis akut, dan prostatitis.',
      fdaDosage: '1 tablet (500mg) setiap 12 jam (2 kali sehari) selama 5-7 hari.',
      fdaSideEffects: 'Mual, diare, ruam kulit, nyeri sendi.',
      fdaWarnings: 'Wajib dihabiskan. Berisiko tendinitis (radang tendon) pada pasien tertentu. Hindari kafein berlebih selama konsumsi.'
    },
    {
      name: 'Cefiget',
      genericName: 'Cefixime',
      activeIngredient: 'Cefixime 100mg',
      category: 'KERAS',
      type: 'PATEN',
      unit: 'tablet',
      sellPrice: 32000,
      buyPrice: 24000,
      requiresPrescription: true,
      description: 'Antibiotik sefalosporin generasi ketiga untuk infeksi bakteri akut.',
      fdaIndications: 'Otitis media, faringitis, tonsilitis, bronkitis akut, dan gonore tanpa komplikasi.',
      fdaDosage: '1 tablet (100mg) dua kali sehari atau 2 tablet sehari sekali selama 7-10 hari.',
      fdaSideEffects: 'Diare, tinja encer, sakit perut, mual, pencernaan terganggu.',
      fdaWarnings: 'Wajib dihabiskan. Hati-hati bagi pasien dengan riwayat alergi penisilin karena adanya risiko sensitivitas silang.'
    }
  ];

  for (const data of drugsData) {
    const existing = await prisma.drug.findFirst({
      where: { name: data.name }
    });

    if (!existing) {
      const created = await prisma.drug.create({ data });
      console.log(`✅ Created drug: ${created.name}`);
    } else {
      const updated = await prisma.drug.update({
        where: { id: existing.id },
        data
      });
      console.log(`🔄 Updated drug details: ${updated.name}`);
    }
  }

  console.log('🌿 Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
