import io

import torch
from fastapi import FastAPI
from fastapi.responses import StreamingResponse

from fastapi.param_functions import Depends
from pydantic import BaseModel
from fastapi import UploadFile
import soundfile as sf


from rzd.tts import TTS
from rzd.stt import STT
from rzd.information_retrieval import Database, Embedder


class STTPayload(BaseModel):
    file: UploadFile


class TextSearchPayload(BaseModel):
    text: str


class TTSPayload(BaseModel):
    text: str


class Endpoints:
    def __init__(self):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        # self.emb = Embedder(model_name_or_path='d0rj/ruRoberta-distilled', device=self.device)
        self.emb = Embedder(model_name_or_path='cointegrated/LaBSE-en-ru', device=self.device)

        self.db = Database(path_to_documents_database='data/documents/appendix_1.csv', embedder=self.emb)
        self.db.init_database()

        self.tts = TTS(self.device)
        self.stt = STT('nvidia/stt_ru_conformer_transducer_large', device=self.device)

    async def audio_to_text(self, data: STTPayload = Depends()) -> str:
        if data.file.content_type != "audio/wav":
            return 'Wrong file format, use WAV'

        audio_data, sample_rate = sf.read(io.BytesIO(await data.file.read()))  # type:ignore
        result = self.stt.stt(audio_data, sample_rate)
        return result

    async def text_query(self, data: TextSearchPayload = Depends()) -> list:
        text = data.text
        df = self.db.search(text)
        result = df.to_dict('records')
        return result  # try to sort this mfker

    async def text_to_audio(self, data: TTSPayload = Depends()) -> StreamingResponse:
        audio = self.tts.get_speech(data.text)

        output = io.BytesIO()
        sf.write(output, audio.numpy(), self.tts.sample_rate, format="WAV")

        output.seek(0)

        return StreamingResponse(io.BytesIO(output.read()), media_type="audio/wav")


app = FastAPI()
endpoints = Endpoints()

app.post("/api/audio_to_text")(
    app.get("/api/audio_to_text")(endpoints.audio_to_text)
)
app.post("/api/text_query")(
    app.get("/api/text_query")(endpoints.text_query)
)
app.post("/api/text_to_audio")(
    app.get("/api/text_to_audio")(endpoints.text_to_audio)
)
# app.post("/api/text_to_audio")(endpoints.text_to_audio)

if __name__ == "__main__":
    # export PYTHONPATH="${PYTHONPATH}:/home/fires/projects/voice_verification/code_sanya/rzd_voice_assistant"
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=6555)
