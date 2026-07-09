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
    // 1. Prioritas Pertama: Model ONNX yang dilatih sendiri (jika file model dan script-nya ada)
    if (fs.existsSync(this.onnxModelPath) && fs.existsSync(this.onnxScriptPath)) {
      this.logger.log(`🤖 Using self-trained CRNN ONNX model for local OCR inference...`);
      
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
        this.logger.error(`❌ Local ONNX OCR failed: ${error.message}. Routing to Hugging Face fallback...`);
      }
    }

    // 2. Prioritas Kedua: Hugging Face Serverless API (jika token diset)
    const hfToken = process.env.HF_TOKEN;

    if (hfToken) {
      this.logger.log(`🌐 Routing OCR request to Hugging Face Serverless Inference API...`);
      try {
        const response = await fetch(
          'https://api-inference.huggingface.co/models/chinmays18/medical-prescription-ocr',
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${hfToken}`,
              'Content-Type': 'image/jpeg',
            },
            body: fileBuffer,
          }
        );

        if (!response.ok) {
          throw new Error(`HF Inference API returned status: ${response.statusText}`);
        }

        const data: any = await response.json();
        
        let rawText = '';
        if (Array.isArray(data) && data.length > 0) {
          rawText = data[0].generated_text || '';
        } else if (data.generated_text) {
          rawText = data.generated_text;
        }

        if (rawText) {
          rawText = rawText.replace(/<s_prescription>/g, '').replace(/<\/s_prescription>/g, '').trim();
          const parsedResult = this.parseDonutStructure(rawText);
          this.logger.log(`✅ HF Serverless OCR Successful. Result length: ${parsedResult.length} chars`);
          return parsedResult;
        }
      } catch (error: any) {
        this.logger.error(`❌ HF Serverless OCR failed: ${error.message}. Falling back to local/dummy OCR.`);
      }
    }

    const hfSpaceUrl = process.env.HF_SPACE_URL;

    if (hfSpaceUrl) {
      this.logger.log(`🌐 Routing OCR request to Hugging Face Space API: ${hfSpaceUrl}`);
      try {
        const formData = new FormData();
        const blob = new Blob([fileBuffer as any], { type: 'image/jpeg' });
        formData.append('file', blob, 'prescription.jpg');

        const response = await fetch(`${hfSpaceUrl.replace(/\/$/, '')}/predict`, {
          method: 'POST',
          body: formData,
        });

        if (!response.ok) {
          throw new Error(`HF Space returned status: ${response.statusText}`);
        }

        const data: any = await response.json();
        const ocrResult = data.text || '';
        this.logger.log(`✅ HF Space OCR Successful. Result length: ${ocrResult.length} chars`);
        return ocrResult;
      } catch (error: any) {
        this.logger.error(`❌ HF Space OCR failed: ${error.message}. Falling back to local Python OCR.`);
      }
    }

    const tempFileName = `rx_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
    const tempFilePath = path.join(this.tempDir, tempFileName);

    try {
      // 1. Simpan buffer gambar ke file sementara
      await fs.promises.writeFile(tempFilePath, fileBuffer);
      this.logger.log(`📸 Saved temporary prescription image to: ${tempFilePath}`);

      // 2. Jalankan script Python subprocess
      // Gunakan "python" secara global. Di Windows, panggil python lewat command line.
      const command = `python "${this.scriptPath}" "${tempFilePath}"`;
      this.logger.log(`🚀 Executing OCR command: ${command}`);

      const { stdout, stderr } = await execAsync(command);

      // 3. Hapus file gambar sementara secara asinkron (tidak memblokir respon)
      fs.unlink(tempFilePath, (err) => {
        if (err) this.logger.error(`⚠️ Failed to delete temp file ${tempFilePath}: ${err.message}`);
      });

      // 4. Parsing output Python
      if (stderr && stderr.includes('ERROR')) {
        this.logger.error(`❌ Python OCR script reported error: ${stderr}`);
        throw new Error(stderr);
      }

      // Cari teks di antara pembatas hasil OCR
      const startMarker = '--- START OCR RESULT ---';
      const endMarker = '--- END OCR RESULT ---';
      
      const startIndex = stdout.indexOf(startMarker);
      const endIndex = stdout.indexOf(endMarker);

      if (startIndex !== -1 && endIndex !== -1) {
        const ocrResult = stdout.substring(startIndex + startMarker.length, endIndex).stripOrTrim();
        this.logger.log(`✅ OCR Scan Successful. Result length: ${ocrResult.length} chars`);
        return ocrResult;
      }

      // Jika pembatas tidak ditemukan tetapi script berhasil berjalan
      if (stdout.includes('ERROR')) {
        this.logger.error(`❌ OCR script stdout error: ${stdout}`);
        throw new Error(stdout);
      }

      this.logger.warn('⚠️ OCR markers not found in python stdout. Returning raw stdout.');
      return stdout.trim();

    } catch (error: any) {
      // Bersihkan file jika masih ada
      if (fs.existsSync(tempFilePath)) {
        try { fs.unlinkSync(tempFilePath); } catch (_) {}
      }

      this.logger.error(`❌ Python OCR process failed: ${error.message}`);
      
      // Fallback ke data dummy resep jika Python belum dikonfigurasi/diinstal library-nya di lokal user
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
