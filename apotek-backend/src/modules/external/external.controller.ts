import {
  Controller, Get, Post,
  Query, Param, UseGuards, Request, ForbiddenException,
  UseInterceptors, UploadedFile
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';
import { DrugSyncService } from './drug-sync.service';
import { OcrService } from './ocr.service';
import { Body } from '@nestjs/common';

@Controller('external')
@UseGuards(AuthGuard('jwt'))
export class ExternalController {
  constructor(
    private rxNormService: RxNormService,
    private fdaService: FdaService,
    private drugSyncService: DrugSyncService,
    private ocrService: OcrService,
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

  // Trigger sync manual (Hanya Super Admin)
  @Post('sync-trigger')
  async triggerSync(@Request() req: any, @Body() body: { category: string }) {
    if (req.user.role !== 'SUPER_ADMIN') {
      throw new ForbiddenException('Hanya Super Admin yang dapat memicu sinkronisasi manual.');
    }
    return this.drugSyncService.triggerSync(body.category || 'all', req.user.name);
  }

  // Ambil riwayat log sinkronisasi
  @Get('sync-logs')
  getSyncLogs() {
    return this.drugSyncService.getSyncLogs();
  }

  // Ambil tren epidemiologi nasional
  @Get('trends')
  getEpidemiologyTrends() {
    return this.drugSyncService.getEpidemiologyTrends();
  }

  // Ambil obat terlaris di apotek
  @Get('top-selling')
  getTopSellingDrugs() {
    return this.drugSyncService.getTopSellingDrugs();
  }

  // Scan gambar resep offline menggunakan ONNX
  @Post('ocr-prescription')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAndScan(@UploadedFile() file: any) {
    if (!file) {
      throw new Error('File resep tidak boleh kosong.');
    }
    const detectedText = await this.ocrService.scanPrescriptionImage(file.buffer);
    
    const lines = detectedText
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

    return { rawText: detectedText, drugs };
  }
}