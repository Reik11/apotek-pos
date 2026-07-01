import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { exec } from 'child_process';
import axios from 'axios';

@Injectable()
export class DrugSyncService {
  private readonly logger = new Logger(DrugSyncService.name);
  private isSyncing = false;

  constructor(
    private prisma: PrismaService,
  ) {}

  // Jadwal otomatis: Setiap Hari Minggu jam 00:00 (Tengah Malam)
  @Cron('0 0 * * 0')
  async scheduledSync() {
    this.logger.log('⏰ Scheduled sync otomatis dimulai...');
    await this.triggerSync('all', 'SYSTEM');
  }

  // Pemicu Sinkronisasi (Manual / Otomatis)
  async triggerSync(category: string, username: string): Promise<{ message: string }> {
    const isProd = process.env.NODE_ENV === 'production';
    
    if (isProd) {
      // PROD: Trigger melalui GitHub Actions
      const owner = 'Reik11'; // Owner repo GitHub
      const repo = 'apotek-pos';   // Nama repo GitHub
      const pat = process.env.GITHUB_PAT; // Personal Access Token disimpan di Env

      if (!pat) {
        this.logger.error('❌ GITHUB_PAT environment variable is missing in Production.');
        throw new Error('Konfigurasi token GitHub tidak ditemukan di server.');
      }

      try {
        await axios.post(
          `https://api.github.com/repos/${owner}/${repo}/dispatches`,
          {
            event_type: 'trigger-scraper',
            client_payload: {
              category: category,
              triggeredBy: username,
            },
          },
          {
            headers: {
              Authorization: `token ${pat}`,
              Accept: 'application/vnd.github.v3+json',
            },
          },
        );
        this.logger.log(`🚀 GitHub Action Dispatch berhasil dikirim oleh ${username} untuk kategori ${category}`);
        return { message: 'Sinkronisasi cloud telah dipicu di GitHub Actions!' };
      } catch (error: any) {
        this.logger.error('❌ Gagal men-trigger GitHub Action dispatch:', error.message);
        throw new Error(`Gagal menghubungi GitHub: ${error.message}`);
      }
    } else {
      // DEV (LOKAL): Spawn child process menjalankan D:\!semester6\!a\scrap_api\scraper.js
      const scriptPath = 'D:\\!semester6\\!a\\scrap_api\\scraper.js';
      const command = `node "${scriptPath}" --category=${category} --triggered-by="${username}"`;
      
      this.logger.log(`💻 Menjalankan scraper lokal di background: ${command}`);
      
      // Gunakan exec untuk spawn process mandiri di OS (async)
      exec(command, (error, stdout, stderr) => {
        if (error) {
          this.logger.error(`❌ Scraper lokal gagal dieksekusi: ${error.message}`);
          return;
        }
        if (stderr) {
          this.logger.warn(`⚠️ Scraper lokal standard error: ${stderr}`);
        }
        this.logger.log(`✅ Scraper lokal berhasil selesai:\n${stdout}`);
      });

      return { message: 'Sinkronisasi lokal telah dijalankan di background!' };
    }
  }

  // Ambil data log sinkronisasi
  async getSyncLogs() {
    return this.prisma.syncLog.findMany({
      orderBy: { startedAt: 'desc' },
      take: 20,
    });
  }

  // Ambil tren epidemiologi nasional
  async getEpidemiologyTrends() {
    return this.prisma.epidemiologyTrend.findMany({
      where: { spatialValue: 'IDN' },
      orderBy: [
        { diseaseCategory: 'asc' },
        { year: 'asc' }
      ],
    });
  }

  // Ambil obat-obat paling laris di apotek lokal
  async getTopSellingDrugs() {
    const items = await this.prisma.transactionItem.groupBy({
      by: ['drugId'],
      _sum: { quantity: true },
      orderBy: { _sum: { quantity: 'desc' } },
      take: 8,
    });

    return Promise.all(
      items.map(async (item) => {
        const drug = await this.prisma.drug.findUnique({
          where: { id: item.drugId },
          select: { name: true, genericName: true },
        });
        return {
          drugId: item.drugId,
          name: drug?.name || 'Obat Tidak Dikenal',
          genericName: drug?.genericName || '-',
          totalSold: item._sum.quantity || 0,
        };
      }),
    );
  }
}