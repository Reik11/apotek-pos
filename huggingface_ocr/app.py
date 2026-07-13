import re
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from transformers import DonutProcessor, VisionEncoderDecoderModel
from PIL import Image
import torch
import io

app = FastAPI(title="ApotekPOS Donut OCR API")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load model globally
model_name = "chinmays18/medical-prescription-ocr"
device = "cuda" if torch.cuda.is_available() else "cpu"

print(f"Loading Donut model {model_name} on {device}...")
processor = DonutProcessor.from_pretrained(model_name)
model = VisionEncoderDecoderModel.from_pretrained(model_name)
model.to(device)
print("Model loaded successfully!")

def clean_json_output(prediction):
    cleaned = re.sub(r'<[^>]+>', ' ', prediction)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned

def parse_donut_structure(prediction):
    drugs = re.findall(r'<s_name>(.*?)</s_name>', prediction)
    dosages = re.findall(r'<s_dosage>(.*?)</s_dosage>', prediction)
    frequencies = re.findall(r'<s_frequency>(.*?)</s_frequency>', prediction)
    
    if drugs:
        lines = []
        for i in range(len(drugs)):
            drug = drugs[i].strip()
            dosage = dosages[i].strip() if i < len(dosages) else ""
            freq = frequencies[i].strip() if i < len(frequencies) else ""
            
            line = f"R/ {drug}"
            if dosage:
                line += f" {dosage}"
            if freq:
                line += f"\nS. {freq}"
            lines.append(line)
        return "\n".join(lines)
        
    return clean_json_output(prediction)

@app.get("/")
def read_root():
    return {"status": "online", "model": model_name, "device": device}

@app.post("/predict")
async def predict_ocr(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        
        task_prompt = "<s_prescription>"
        decoder_input_ids = processor.tokenizer(task_prompt, add_special_tokens=False, return_tensors="pt").input_ids
        pixel_values = processor(image, return_tensors="pt").pixel_values
        
        pixel_values = pixel_values.to(device)
        decoder_input_ids = decoder_input_ids.to(device)
        
        with torch.no_grad():
            outputs = model.generate(
                pixel_values,
                decoder_input_ids=decoder_input_ids,
                max_length=model.config.decoder.max_position_embeddings,
                pad_token_id=processor.tokenizer.pad_token_id,
                eos_token_id=processor.tokenizer.eos_token_id,
                use_cache=True,
                bad_words_ids=[[processor.tokenizer.unk_token_id]],
                return_dict_in_generate=True,
            )
            
        sequence = processor.batch_decode(outputs.sequences)[0]
        sequence = sequence.replace(processor.tokenizer.eos_token, "").replace(processor.tokenizer.pad_token, "")
        sequence = re.sub(r"<.*?>", "", sequence, count=1).strip()
        
        formatted_text = parse_donut_structure(sequence)
        if not formatted_text.strip():
            formatted_text = clean_json_output(sequence)
            
        return {"text": formatted_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR Inference Failed: {str(e)}")
