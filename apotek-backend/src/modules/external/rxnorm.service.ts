import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class RxNormService {
  private readonly logger = new Logger(RxNormService.name);
  private readonly baseUrl = 'https://rxnav.nlm.nih.gov/REST';

  async searchByName(name: string): Promise<any[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/drugs.json?name=${encodeURIComponent(name)}`
      );

      const drugGroup = response.data?.drugGroup;
      if (!drugGroup?.conceptGroup) return [];

      const results: any[] = [];
      for (const group of drugGroup.conceptGroup) {
        if (group.conceptProperties) {
          for (const prop of group.conceptProperties) {
            results.push({
              rxcui: prop.rxcui,
              name: prop.name,
              synonym: prop.synonym || '',
              tty: prop.tty,
            });
          }
        }
      }
      return results.slice(0, 10);
    } catch (error) {
      this.logger.error('RxNorm search error:', error.message);
      return [];
    }
  }

  async getDrugDetails(rxcui: string): Promise<any | null> {
    try {
      const propResponse = await axios.get(
        `${this.baseUrl}/rxcui/${rxcui}/properties.json`
      );
      const properties = propResponse.data?.properties;

      const ingredientResponse = await axios.get(
        `${this.baseUrl}/rxcui/${rxcui}/related.json?tty=IN`
      );
      const ingredientGroup =
        ingredientResponse.data?.relatedGroup?.conceptGroup || [];

      const ingredients: string[] = [];
      for (const group of ingredientGroup) {
        if (group.conceptProperties) {
          for (const prop of group.conceptProperties) {
            ingredients.push(prop.name);
          }
        }
      }

      return {
        rxcui,
        name: properties?.name || '',
        synonym: properties?.synonym || '',
        ingredients: ingredients.join(', '),
      };
    } catch (error) {
      this.logger.error('RxNorm detail error:', error.message);
      return null;
    }
  }

  async getGenericAlternatives(rxcui: string): Promise<any[]> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/rxcui/${rxcui}/related.json?tty=SBD+SBDC`
      );

      const groups = response.data?.relatedGroup?.conceptGroup || [];
      const alternatives: any[] = [];

      for (const group of groups) {
        if (group.conceptProperties) {
          for (const prop of group.conceptProperties) {
            alternatives.push({
              rxcui: prop.rxcui,
              name: prop.name,
            });
          }
        }
      }
      return alternatives.slice(0, 5);
    } catch (error) {
      this.logger.error('RxNorm alternatives error:', error.message);
      return [];
    }
  }
}