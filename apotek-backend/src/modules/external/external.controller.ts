import { Controller, Get, Post, Query, Param, Body, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { RxNormService } from './rxnorm.service';
import { FdaService } from './fda.service';

@Controller('external')
@UseGuards(AuthGuard('jwt'))
export class ExternalController {
  constructor(
    private rxNormService: RxNormService,
    private fdaService: FdaService,
  ) {}

  @Get('rxnorm/search')
  searchRxNorm(@Query('name') name: string) {
    return this.rxNormService.searchByName(name);
  }

  @Get('rxnorm/:rxcui')
  getRxNormDetail(@Param('rxcui') rxcui: string) {
    return this.rxNormService.getDrugDetails(rxcui);
  }

  @Get('rxnorm/:rxcui/alternatives')
  getAlternatives(@Param('rxcui') rxcui: string) {
    return this.rxNormService.getGenericAlternatives(rxcui);
  }

  @Get('fda/label')
  getFdaLabel(@Query('name') name: string) {
    return this.fdaService.getDrugLabel(name);
  }

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
      rxnorm: {
        results: rxnormResults,
        detail: rxnormDetail,
      },
      fda: fdaLabel,
    };
  }

  @Post('ocr-analyze')
  async analyzeOcr(@Body() body: { text: string }) {
    const lines = body.text
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 2);

    const drugs = [];

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
}