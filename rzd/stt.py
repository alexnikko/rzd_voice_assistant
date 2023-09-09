import io

import nemo.collections.asr as nemo_asr
import numpy as np
import soundfile as sf
from librosa import resample
import librosa
import torch
import os
from typing import Union


class STT:
    def __init__(self, model_name: str, device: Union[str, torch.device] = 'cpu'):
        self.model = nemo_asr.models.EncDecRNNTBPEModel.from_pretrained(model_name)
        self.device = device

    # def text_from_audio(self, data, ):

    def get_text(self, path_to_audio: str) -> str:
        a, sr = sf.read(path_to_audio, always_2d=True)

        a = a.mean(axis=1)

        a = resample(a, orig_sr=sr, target_sr=16_000)
        sf.write('data/input_audio_examples/tmp.wav', a, samplerate=16_000)

        text = self.model.transcribe(['data/input_audio_examples/tmp.wav'])[0]

        os.remove('data/input_audio_examples/tmp.wav')
        return text

    def stt(self, a: np.ndarray, sr: float) -> np.ndarray:
        a = a.mean(axis=1)
        a = resample(a, orig_sr=sr, target_sr=16_000)
        sf.write('/tmp/tmp.wav', a, samplerate=16_000)
        text = self.model.transcribe(['/tmp/tmp.wav'])[0]
        return text


if __name__ == '__main__':
    model_name = 'nvidia/stt_ru_conformer_transducer_large'
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    stt = STT(model_name, device)
    path_to_audio = 'data/input_audio_examples/Не включилось ру6.wav'
    text = stt.get_text(path_to_audio)
    print(text)
