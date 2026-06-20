import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class FdaService {
  private readonly logger = new Logger(FdaService.name);
  private readonly baseUrl = 'https://api.fda.gov/drug/label.json';

  // Ambil info label obat dari FDA
  async getDrugLabel(drugName: string) {
    try {
      const response = await axios.get(
        `${this.baseUrl}?search=openfda.generic_name:"${encodeURIComponent(drugName)}"&limit=1`
      );

      const result = response.data?.results?.[0];
      if (!result) return null;

      return {
        purpose: result.purpose?.[0] || null,
        indications: result.indications_and_usage?.[0] || null,
        warnings: result.warnings?.[0] || null,
        dosage: result.dosage_and_administration?.[0] || null,
        sideEffects: result.adverse_reactions?.[0] || null,
        contraindications: result.contraindications?.[0] || null,
        activeIngredient: result.active_ingredient?.[0] || null,
      };
    } catch (error) {
      // Coba cari dengan brand name
      try {
        const response = await axios.get(
          `${this.baseUrl}?search=openfda.brand_name:"${encodeURIComponent(drugName)}"&limit=1`
        );
        const result = response.data?.results?.[0];
        if (!result) return null;

        return {
          purpose: result.purpose?.[0] || null,
          indications: result.indications_and_usage?.[0] || null,
          warnings: result.warnings?.[0] || null,
          dosage: result.dosage_and_administration?.[0] || null,
          sideEffects: result.adverse_reactions?.[0] || null,
          contraindications: result.contraindications?.[0] || null,
          activeIngredient: result.active_ingredient?.[0] || null,
        };
      } catch {
        this.logger.error('FDA label error:', error.message);
        return null;
      }
    }
  }

  // Ambil recall obat terbaru dari FDA
  async getRecentRecalls() {
    try {
      const response = await axios.get(
        'https://api.fda.gov/drug/enforcement.json?limit=5'
      );
      return response.data?.results || [];
    } catch (error) {
      this.logger.error('FDA recalls error:', error.message);
      return [];
    }
  }
}