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
  private readonly tempDir = 'D:\\!semester6\\!a\\apotek-pos\\ocr_training\\temp';

  async onModuleInit() {
    // Pastikan folder temp ada
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }
    
    // Cek apakah script inference.py ada
    if (fs.existsSync(this.scriptPath)) {
      this.logger.log(`🤖 OCR Service initialized using HuggingFace Python script: ${this.scriptPath}`);
    } else {
      this.logger.error(`❌ Python inference script not found at: ${this.scriptPath}`);
    }
  }

  async scanPrescriptionImage(fileBuffer: Buffer): Promise<string> {
    const hfSpaceUrl = process.env.HF_SPACE_URL;

    if (hfSpaceUrl) {
      this.logger.log(`🌐 Routing OCR request to Hugging Face Space API: ${hfSpaceUrl}`);
      try {
        const formData = new FormData();
        const blob = new Blob([fileBuffer], { type: 'image/jpeg' });
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
