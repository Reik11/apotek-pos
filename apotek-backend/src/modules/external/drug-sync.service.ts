import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';

@Injectable()
export class DrugSyncService {
  private readonly logger = new Logger(DrugSyncService.name);
  private isSyncing = false;

  constructor(
    private prisma: PrismaService,
    private rxNormService: RxNormService,
    private fdaService: FdaService,
  ) {}

  // Jadwal otomatis: Senin & Kamis jam 02:00 pagi
  @Cron('0 2 * * 1,4')
  async scheduledSync() {
    this.logger.log('⏰ Scheduled sync dimulai...');
    await this.syncAllDrugs();
  }

  // Sync semua obat
  async syncAllDrugs(): Promise<void> {
    if (this.isSyncing) {
      this.logger.warn('⚠️ Sync sedang berjalan, skip!');
      return;
    }

    this.isSyncing = true;
    this.logger.log('🔄 Mulai sync data obat dari API...');

    try {
      const drugs = await this.prisma.drug.findMany({
        where: { isActive: true },
        select: {
          id: true,
          name: true,
          genericName: true,
          rxcui: true,
        },
      });

      this.logger.log(`📦 Total obat: ${drugs.length}`);

      let success = 0;
      let fail = 0;

      for (const drug of drugs) {
        try {
          await this.syncOneDrug(drug);
          success++;
          // Delay 600ms agar tidak spam API
          await this.delay(600);
        } catch (e) {
          this.logger.error(`❌ Gagal sync ${drug.name}`);
          fail++;
        }
      }

      this.logger.log(
        `✅ Sync selesai! Berhasil: ${success}, Gagal: ${fail}`,
      );
    } finally {
      this.isSyncing = false;
    }
  }

  // Sync satu obat by object
  async syncOneDrug(drug: {
    id: string;
    name: string;
    genericName?: string | null;
    rxcui?: string | null;
  }): Promise<void> {
    const searchName = drug.genericName || drug.name;
    const updateData: any = { lastApiSync: new Date() };

    // 1. Cari di RxNorm
    try {
      const rxnormResults =
        await this.rxNormService.searchByName(searchName);

      if (rxnormResults.length > 0) {
        const first = rxnormResults[0];
        updateData.rxcui = first.rxcui;
        updateData.rxnormName = first.name;

        // Ambil ingredients
        await this.delay(300);
        const detail = await this.rxNormService.getDrugDetails(
          first.rxcui,
        );
        if (detail?.ingredients) {
          updateData.rxnormIngredients = detail.ingredients;
        }
      }
    } catch (e) {
      this.logger.warn(`RxNorm gagal untuk ${drug.name}`);
    }

    // 2. Cari di FDA
    try {
      await this.delay(300);
      const fda = await this.fdaService.getDrugLabel(searchName);
      if (fda) {
        updateData.fdaIndications =
          fda.indications?.substring(0, 1000) ?? null;
        updateData.fdaSideEffects =
          fda.sideEffects?.substring(0, 500) ?? null;
        updateData.fdaDosage =
          fda.dosage?.substring(0, 500) ?? null;
        updateData.fdaWarnings =
          fda.warnings?.substring(0, 500) ?? null;
        updateData.fdaContraindications =
          fda.contraindications?.substring(0, 500) ?? null;
      }
    } catch (e) {
      this.logger.warn(`FDA gagal untuk ${drug.name}`);
    }

    // 3. Simpan ke database
    await this.prisma.drug.update({
      where: { id: drug.id },
      data: updateData,
    });

    this.logger.log(`✅ ${drug.name} — sync berhasil`);
  }

  // Sync satu obat by ID
  async syncOneDrugById(drugId: string): Promise<void> {
    const drug = await this.prisma.drug.findUnique({
      where: { id: drugId },
      select: {
        id: true,
        name: true,
        genericName: true,
        rxcui: true,
      },
    });
    if (!drug) return;
    await this.syncOneDrug(drug);
  }

  // Cek status sync
  getSyncStatus() {
    return {
      isSyncing: this.isSyncing,
      schedule: 'Senin & Kamis jam 02:00 pagi',
    };
  }

  private delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}