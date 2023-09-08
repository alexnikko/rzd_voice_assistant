import nemo.collections.asr as nemo_asr
import soundfile as sf
from librosa import resample
import os

class STT:
    def __init__(self, model_name: str, device: str = 'cpu'):
        self.model = nemo_asr.models.EncDecRNNTBPEModel.from_pretrained(model_name)

    def get_text(self, path_to_audio: str) -> str:
        a, sr = sf.read(path_to_audio, always_2d=True)
        a = a.mean(axis=1)

        a = resample(a, orig_sr=sr, target_sr=16_000)
        sf.write('input_audio_examples/tmp.wav', a, samplerate=16_000)

        text = self.model.transcribe(['input_audio_examples/tmp.wav'])[0]

        os.remove('input_audio_examples/tmp.wav')
        return text


if __name__ == '__main__':
    model_name = 'nvidia/stt_ru_conformer_transducer_large'
    device = 'cpu'
    stt = STT(model_name, device)
    path_to_audio = 'input_audio_examples/Не включилось ру6.wav'
    text = stt.get_text(path_to_audio)
    print(text)
