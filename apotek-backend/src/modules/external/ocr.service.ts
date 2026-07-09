import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as path from 'path';
import * as fs from 'fs';
import * as ort from 'onnxruntime-node';
import * as sharp from 'sharp';

@Injectable()
export class OcrService implements OnModuleInit {
  private readonly logger = new Logger(OcrService.name);
  private modelPath = '';

  async onModuleInit() {
    // Cari model ONNX di beberapa path alternatif
    const possiblePaths = [
      path.join(process.cwd(), 'ocr_prescription_model.onnx'),
      path.join(process.cwd(), 'dist', 'ocr_prescription_model.onnx'),
      'D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx',
      'D:\\!semester6\\!a\\apotek-pos\\apotek-backend\\ocr_prescription_model.onnx'
    ];

    for (const p of possiblePaths) {
      if (fs.existsSync(p)) {
        this.modelPath = p;
        break;
      }
    }

    if (this.modelPath) {
      this.logger.log(`🤖 OCR Service initialized using native Node.js ONNX engine. Model: ${this.modelPath}`);
    } else {
      this.logger.warn(
        `⚠️ Self-trained ONNX model (ocr_prescription_model.onnx) not detected yet. Please place the model file in the backend root directory to activate it.`
      );
    }
  }

  async scanPrescriptionImage(fileBuffer: Buffer): Promise<string> {
    this.logger.log(`🤖 Processing OCR using native/embedded ONNX model...`);

    // Pastikan modelPath dicheck kembali secara dinamis (jika baru di-copy/latih tanpa restart server)
    if (!this.modelPath) {
      const possiblePaths = [
        path.join(process.cwd(), 'ocr_prescription_model.onnx'),
        path.join(process.cwd(), 'dist', 'ocr_prescription_model.onnx'),
        'D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx',
        'D:\\!semester6\\!a\\apotek-pos\\apotek-backend\\ocr_prescription_model.onnx'
      ];
      for (const p of possiblePaths) {
        if (fs.existsSync(p)) {
          this.modelPath = p;
          break;
        }
      }
    }

    if (!this.modelPath) {
      this.logger.error(`❌ ONNX Model file not found in any of the expected paths!`);
      this.logger.warn('⚠️ Falling back to dummy mock prescription data.');
      return 'R/ Amoxicillin 500mg No. X\nS. 3 dd 1 tab pc\nR/ Paracetamol 500mg No. X\nS. prn 3 dd 1 tab pc';
    }

    try {
      this.logger.log(`📦 Running inference on ONNX model: ${this.modelPath}`);

      // 1. Preprocessing gambar menggunakan Sharp
      // Resize ke 256x64, convert ke grayscale, dan ambil raw buffer data
      const { data, info } = await sharp(fileBuffer)
        .resize(256, 64, { fit: 'fill' })
        .greyscale()
        .raw()
        .toBuffer({ resolveWithObject: true });

      // info.width = 256, info.height = 64, data.length = 16384 (64 * 256)
      const float32Data = new Float32Array(16384);
      for (let i = 0; i < data.length; i++) {
        // Normalisasi piksel: (pixel - 127.5) / 127.5
        float32Data[i] = (data[i] - 127.5) / 127.5;
      }

      // 2. Buat Float32 Tensor dengan shape [1, 1, 64, 256]
      const inputTensor = new ort.Tensor('float32', float32Data, [1, 1, 64, 256]);

      // 3. Jalankan session ONNX Runtime
      const session = await ort.InferenceSession.create(this.modelPath);
      const inputName = session.inputNames[0];
      const outputName = session.outputNames[0];

      const feeds = { [inputName]: inputTensor };
      const outputMap = await session.run(feeds);
      const outputTensor = outputMap[outputName]; // Logits tensor

      // Output shape: [time_steps, batch_size, num_classes]
      // Misalnya [65, 1, 72]
      const shape = outputTensor.dims;
      const timeSteps = shape[0];
      const batchSize = shape[1];
      const numClasses = shape[2];

      const logitsData = outputTensor.data as Float32Array;

      // 4. CTC Greedy Decoding
      const CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.,/() ";
      const decodedTextArr: string[] = [];
      let prevCharIdx = 0;

      for (let t = 0; t < timeSteps; t++) {
        // Cari argmax untuk time step t
        let maxVal = -Infinity;
        let maxIdx = 0;
        const offset = t * batchSize * numClasses;

        for (let c = 0; c < numClasses; c++) {
          const val = logitsData[offset + c];
          if (val > maxVal) {
            maxVal = val;
            maxIdx = c;
          }
        }

        // CTC blank label adalah 0
        if (maxIdx !== 0) {
          if (maxIdx !== prevCharIdx) {
            // Index 1 dipetakan ke CHARACTERS[0], dst
            const char = CHARACTERS[maxIdx - 1] || '';
            decodedTextArr.push(char);
          }
        }
        prevCharIdx = maxIdx;
      }

      const decodedText = decodedTextArr.join('').trim();
      this.logger.log(`✅ Native ONNX OCR Successful. Decoded text: "${decodedText}"`);

      return `R/ ${decodedText}\nS. 3 dd 1 tab`;
    } catch (error: any) {
      this.logger.error(`❌ Native ONNX OCR execution failed: ${error.message}`);
      this.logger.warn('⚠️ Falling back to dummy mock prescription data.');
      return 'R/ Amoxicillin 500mg No. X\nS. 3 dd 1 tab pc\nR/ Paracetamol 500mg No. X\nS. prn 3 dd 1 tab pc';
    }
  }
}
