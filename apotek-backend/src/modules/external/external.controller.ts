import {
  Controller, Get, Post,
  Query, Param, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';
import { DrugSyncService } from './drug-sync.service';
import { Body } from '@nestjs/common';

@Controller('external')
@UseGuards(AuthGuard('jwt'))
export class ExternalController {
  constructor(
    private rxNormService: RxNormService,
    private fdaService: FdaService,
    private drugSyncService: DrugSyncService,
  ) {}

  // Cari obat di RxNorm
  @Get('rxnorm/search')
  searchRxNorm(@Query('name') name: string) {
    return this.rxNormService.searchByName(name);
  }

  // Detail obat dari RxNorm
  @Get('rxnorm/:rxcui')
  getRxNormDetail(@Param('rxcui') rxcui: string) {
    return this.rxNormService.getDrugDetails(rxcui);
  }

  // Alternatif generik
  @Get('rxnorm/:rxcui/alternatives')
  getAlternatives(@Param('rxcui') rxcui: string) {
    return this.rxNormService.getGenericAlternatives(rxcui);
  }

  // Info recall dari FDA
  @Get('fda/recalls')
  getFdaRecalls() {
    return this.fdaService.getRecentRecalls();
  }

  // Info label dari FDA
  @Get('fda/label')
  getFdaLabel(@Query('name') name: string) {
    return this.fdaService.getDrugLabel(name);
  }

  // Info lengkap gabungan RxNorm + FDA
  @Get('drug-info')
  async getDrugInfo(@Query('name') name: string) {
    const [rxnormResults, fdaLabel] = await Promise.all([
      this.rxNormService.searchByName(name),
      this.fdaService.getDrugLabel(name),
    ]);

    let rxnormDetail: any = null;
    if (rxnormResults.length > 0) {
      rxnormDetail = await this.rxNormService.getDrugDetails(
        rxnormResults[0].rxcui,
      );
    }

    return {
      rxnorm: { results: rxnormResults, detail: rxnormDetail },
      fda: fdaLabel,
    };
  }

  // OCR analyze
  @Post('ocr-analyze')
  async analyzeOcr(@Body() body: { text: string }) {
    const lines = body.text
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 2);

    const drugs: any[] = [];

    for (const line of lines.slice(0, 10)) {
      try {
        const results = await this.rxNormService.searchByName(line);
        if (results.length > 0) {
          drugs.push({
            detectedName: line,
            rxnorm: results[0],
            localDrugs: [],
          });
        }
      } catch (e) {
        continue;
      }
    }

    return { drugs };
  }

  // ===== SYNC ENDPOINTS =====

  // Cek status sync
  @Get('sync/status')
  getSyncStatus() {
    return this.drugSyncService.getSyncStatus();
  }

  // Trigger sync semua obat manual
  @Post('sync/all')
  syncAllDrugs() {
    // Jalankan di background, tidak perlu tunggu
    this.drugSyncService.syncAllDrugs();
    return {
      message: 'Sync dimulai di background!',
      note: 'Cek status di GET /external/sync/status',
    };
  }

  // Sync satu obat by ID
  @Post('sync/drug/:id')
  async syncOneDrug(@Param('id') id: string) {
    await this.drugSyncService.syncOneDrugById(id);
    return { message: 'Sync berhasil!' };
  }
}