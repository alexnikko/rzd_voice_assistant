import torch
import soundfile as sf
from typing import Union


class TTS:
    def __init__(self, speaker: str, language: str, device: Union[str, torch.device]):
        self.model, self.symbols, self.sample_rate, _, self.apply_tts = torch.hub.load(
            repo_or_dir='snakers4/silero-models',
            model='silero_tts',
            language=language,
            speaker=speaker,
        )
        self.model.to(torch.device(device))
        self.device = device

    def get_speech(self, text: str, speaker: str = 'xenia',
                   put_accent: bool = True, put_yo: bool = True):
        audio = self.apply_tts(
            texts=[text],
            model=self.model,
            sample_rate=self.sample_rate,
            symbols=self.symbols,
            device=self.device
        )
        return audio[0]


if __name__ == '__main__':
    speaker = 'kseniya_16khz'
    language = 'ru'
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    tts = TTS(speaker, language, device)
    text = 'машинист электропоезда находится в хорошей физической форме'
    audio = tts.get_speech(text)
    print(audio)
    sf.write('data/output_audio_examples/examples_1.wav', audio.numpy(), samplerate=tts.sample_rate)
