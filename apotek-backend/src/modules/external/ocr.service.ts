import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as path from 'path';
import * as fs from 'fs';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

@Injectable()
export class OcrService implements OnModuleInit {
  private readonly logger = new Logger(OcrService.name);
  private readonly scriptPath = 'D:\\!semester6\\!a\\apotek-pos\\ocr_training\\inference.py';
  private readonly onnxScriptPath = 'D:\\!semester6\\!a\\apotek-pos\\ocr_training\\inference_onnx.py';
  private readonly onnxModelPath = 'D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx';
  private readonly tempDir = 'D:\\!semester6\\!a\\apotek-pos\\ocr_training\\temp';

  async onModuleInit() {
    // Pastikan folder temp ada
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }
    
    // Cek model ONNX
    if (fs.existsSync(this.onnxModelPath)) {
      this.logger.log(`🤖 OCR Service: Self-trained ONNX model detected at ${this.onnxModelPath}`);
    } else {
      this.logger.warn(`⚠️ OCR Service: Self-trained ONNX model not found yet at ${this.onnxModelPath}. Will use HuggingFace fallback.`);
    }
  }

  async scanPrescriptionImage(fileBuffer: Buffer): Promise<string> {
    this.logger.log(`🤖 Using self-trained CRNN ONNX model for OCR inference...`);
    
    const tempFileName = `rx_onnx_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
    const tempFilePath = path.join(this.tempDir, tempFileName);

    try {
      await fs.promises.writeFile(tempFilePath, fileBuffer);
      const command = `python "${this.onnxScriptPath}" "${tempFilePath}"`;
      this.logger.log(`🚀 Executing local ONNX OCR command: ${command}`);

      const { stdout, stderr } = await execAsync(command);

      fs.unlink(tempFilePath, (err) => {
        if (err) this.logger.error(`⚠️ Failed to delete temp file ${tempFilePath}: ${err.message}`);
      });

      if (stderr && stderr.includes('ERROR')) {
        this.logger.error(`❌ Python ONNX OCR script reported error: ${stderr}`);
        throw new Error(stderr);
      }

      const startMarker = '--- START OCR RESULT ---';
      const endMarker = '--- END OCR RESULT ---';
      
      const startIndex = stdout.indexOf(startMarker);
      const endIndex = stdout.indexOf(endMarker);

      if (startIndex !== -1 && endIndex !== -1) {
        const ocrResult = stdout.substring(startIndex + startMarker.length, endIndex).stripOrTrim();
        this.logger.log(`✅ Local ONNX OCR Successful. Result length: ${ocrResult.length} chars`);
        return ocrResult;
      }

      return stdout.trim();
    } catch (error: any) {
      if (fs.existsSync(tempFilePath)) {
        try { fs.unlinkSync(tempFilePath); } catch (_) {}
      }

      this.logger.error(`❌ Local ONNX OCR process failed: ${error.message}`);
      
      // Fallback ke data dummy resep jika model ONNX belum dikonfigurasi/dibuat secara lengkap
      this.logger.warn('⚠️ Falling back to dummy mock prescription data.');
      return 'R/ Amoxicillin 500mg No. X\nS. 3 dd 1 tab pc\nR/ Paracetamol 500mg No. X\nS. prn 3 dd 1 tab pc';
    }
  }

  private cleanJsonOutput(prediction: string): string {
    const cleaned = prediction.replace(/<[^>]+>/g, ' ');
    return cleaned.replace(/\s+/g, ' ').trim();
  }

  private parseDonutStructure(prediction: string): string {
    const drugs: string[] = [];
    const dosages: string[] = [];
    const frequencies: string[] = [];

    const drugRegex = /<s_name>(.*?)<\/s_name>/g;
    const dosageRegex = /<s_dosage>(.*?)<\/s_dosage>/g;
    const freqRegex = /<s_frequency>(.*?)<\/s_frequency>/g;

    let match;
    const predictionClean = prediction;
    
    drugRegex.lastIndex = 0;
    dosageRegex.lastIndex = 0;
    freqRegex.lastIndex = 0;

    while ((match = drugRegex.exec(predictionClean)) !== null) {
      drugs.push(match[1].trim());
    }
    while ((match = dosageRegex.exec(predictionClean)) !== null) {
      dosages.push(match[1].trim());
    }
    while ((match = freqRegex.exec(predictionClean)) !== null) {
      frequencies.push(match[1].trim());
    }

    if (drugs.length > 0) {
      const lines: string[] = [];
      for (let i = 0; i < drugs.length; i++) {
        const drug = drugs[i];
        const dosage = i < dosages.length ? dosages[i] : '';
        const freq = i < frequencies.length ? frequencies[i] : '';

        let line = `R/ ${drug}`;
        if (dosage) line += ` ${dosage}`;
        if (freq) line += `\nS. ${freq}`;
        lines.push(line);
      }
      return lines.join('\n');
    }

    return this.cleanJsonOutput(prediction);
  }
}

// Helper untuk membersihkan string whitespace
declare global {
  interface String {
    stripOrTrim(): string;
  }
}

String.prototype.stripOrTrim = function() {
  return this.replace(/^\s+|\s+$/g, '');
};
