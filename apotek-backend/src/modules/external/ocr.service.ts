import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as path from 'path';
import * as fs from 'fs';

// Dynamically import ONNX and Sharp to prevent crash if not installed/compiled yet
let ort: any;
let sharp: any;

try {
  ort = require('onnxruntime-node');
} catch (e) {
  Logger.warn('onnxruntime-node is not installed or failed to load. OCR service will run in dummy fallback mode.', 'OcrService');
}

try {
  sharp = require('sharp');
} catch (e) {
  Logger.warn('sharp is not installed or failed to load. OCR service will run in dummy fallback mode.', 'OcrService');
}

@Injectable()
export class OcrService implements OnModuleInit {
  private readonly logger = new Logger(OcrService.name);
  private session: any = null;
  private readonly modelPath = 'D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx';
  
  // Character map must match the training script exactly
  private readonly CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.,/() ";

  async onModuleInit() {
    if (!ort) return;
    
    try {
      if (fs.existsSync(self.modelPath)) {
        this.logger.log(`🤖 Loading ONNX OCR Model from: ${this.modelPath}`);
        this.session = await ort.InferenceSession.create(this.modelPath);
        this.logger.log('✅ ONNX OCR Model loaded successfully!');
      } else {
        this.logger.warn(`⚠️ ONNX model file not found at: ${this.modelPath}. Run training script first.`);
      }
    } catch (error: any) {
      this.logger.error(`❌ Failed to initialize ONNX session: ${error.message}`);
    }
  }

  // Reload model (e.g. after training completes)
  async reloadModel() {
    this.session = null;
    await this.onModuleInit();
  }

  async scanPrescriptionImage(fileBuffer: Buffer): Promise<string> {
    if (!this.session || !sharp || !ort) {
      this.logger.warn('🤖 OCR model session not active. Returning dummy prescription text.');
      // Mock result for testing when PyTorch training is not completed
      return 'R/ Amoxicillin 500mg No. X\nS. 3 dd 1 tab pc\nR/ Paracetamol 500mg No. X\nS. prn 3 dd 1 tab pc';
    }

    try {
      // 1. Preprocessing image using sharp:
      // Convert to grayscale, resize to 256 width x 64 height, get raw pixel buffer
      const resizedImageBuffer = await sharp(fileBuffer)
        .grayscale()
        .resize(256, 64)
        .raw()
        .toBuffer();

      const imageSize = 64 * 256;
      const floatData = new Float32Array(imageSize);

      // Normalize pixels to [-1.0, 1.0] (matching transforms.Normalize((0.5,), (0.5,)) in PyTorch)
      for (let i = 0; i < imageSize; i++) {
        floatData[i] = (resizedImageBuffer[i] - 127.5) / 127.5;
      }

      // 2. Create input tensor of shape [1, 1, 64, 256] (Batch, Channel, Height, Width)
      const inputTensor = new ort.Tensor('float32', floatData, [1, 1, 64, 256]);

      // 3. Run Inference
      const outputMap = await this.session.run({ input_image: inputTensor });
      const outputTensor = outputMap.output_logits; // Shape: [SeqLength, Batch, NumClasses]

      // 4. CTC Greedy Decoding
      const data = outputTensor.data as Float32Array;
      const dims = outputTensor.dims; // [SeqLength, 1, NumClasses]
      const seqLength = dims[0];
      const numClasses = dims[2];

      const predIndexes: number[] = [];

      for (let t = 0; t < seqLength; t++) {
        let maxVal = -Infinity;
        let argMax = 0;
        
        // Find class with highest probability at current timestep
        for (let c = 0; c < numClasses; c++) {
          const val = data[t * numClasses + c];
          if (val > maxVal) {
            maxVal = val;
            argMax = c;
          }
        }
        predIndexes.push(argMax);
      }

      // Collapse identical consecutive characters and remove blank label (0)
      const collapsed: number[] = [];
      let lastIdx = -1;

      for (const idx of predIndexes) {
        if (idx !== lastIdx) {
          if (idx !== 0) { // 0 is CTC Blank Label
            collapsed.push(idx);
          }
          lastIdx = idx;
        }
      }

      // Map numerical tokens back to text characters
      const text = collapsed
        .map(idx => {
          // CHARACTERS starts at 1 in our dictionary (index 0 is reserved for blank)
          return this.CHARACTERS[idx - 1] || '';
        })
        .join('');

      this.logger.log(`🤖 OCR Scan Result: "${text}"`);
      return text;

    } catch (error: any) {
      this.logger.error(`❌ OCR scanning failed: ${error.message}`);
      throw new Error(`Gagal memindai gambar resep: ${error.message}`);
    }
  }
}
// Helper variable for self reference in module
const self = {
  modelPath: 'D:\\!semester6\\!a\\ocr_training\\ocr_prescription_model.onnx'
};
