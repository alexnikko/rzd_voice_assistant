import os
import pandas as pd
import torch
import soundfile as sf
from typing import Union
import re
import numpy as np

import decimal

units = (
    u'ноль',

    (u'один', u'одна'),
    (u'два', u'две'),

    u'три', u'четыре', u'пять',
    u'шесть', u'семь', u'восемь', u'девять'
)

teens = (
    u'десять', u'одиннадцать',
    u'двенадцать', u'тринадцать',
    u'четырнадцать', u'пятнадцать',
    u'шестнадцать', u'семнадцать',
    u'восемнадцать', u'девятнадцать'
)

tens = (
    teens,
    u'двадцать', u'тридцать',
    u'сорок', u'пятьдесят',
    u'шестьдесят', u'семьдесят',
    u'восемьдесят', u'девяносто'
)

hundreds = (
    u'сто', u'двести',
    u'триста', u'четыреста',
    u'пятьсот', u'шестьсот',
    u'семьсот', u'восемьсот',
    u'девятьсот'
)

orders = (  # plural forms and gender
    # ((u'', u'', u''), 'm'), # ((u'рубль', u'рубля', u'рублей'), 'm'), # ((u'копейка', u'копейки', u'копеек'), 'f')
    ((u'тысяча', u'тысячи', u'тысяч'), 'f'),
    ((u'миллион', u'миллиона', u'миллионов'), 'm'),
    ((u'миллиард', u'миллиарда', u'миллиардов'), 'm'),
)

minus = u'минус'


def thousand(rest, sex):
    """Converts numbers from 19 to 999"""
    prev = 0
    plural = 2
    name = []
    use_teens = rest % 100 >= 10 and rest % 100 <= 19
    if not use_teens:
        data = ((units, 10), (tens, 100), (hundreds, 1000))
    else:
        data = ((teens, 10), (hundreds, 1000))
    for names, x in data:
        cur = int(((rest - prev) % x) * 10 / x)
        prev = rest % x
        if x == 10 and use_teens:
            plural = 2
            name.append(teens[cur])
        elif cur == 0:
            continue
        elif x == 10:
            name_ = names[cur]
            if isinstance(name_, tuple):
                name_ = name_[0 if sex == 'm' else 1]
            name.append(name_)
            if cur >= 2 and cur <= 4:
                plural = 1
            elif cur == 1:
                plural = 0
            else:
                plural = 2
        else:
            name.append(names[cur - 1])
    return plural, name


def num2text(num, main_units=((u'', u'', u''), 'm')):
    """
    http://ru.wikipedia.org/wiki/Gettext#.D0.9C.D0.BD.D0.BE.D0.B6.D0.B5.D1.81.\
    D1.82.D0.B2.D0.B5.D0.BD.D0.BD.D1.8B.D0.B5_.D1.87.D0.B8.D1.81.D0.BB.D0.B0_2
    """
    _orders = (main_units,) + orders
    if num == 0:
        return ' '.join((units[0], _orders[0][0][2])).strip()  # ноль

    rest = abs(num)
    ord = 0
    name = []
    while rest > 0:
        plural, nme = thousand(rest % 1000, _orders[ord][1])
        if nme or ord == 0:
            name.append(_orders[ord][0][plural])
        name += nme
        rest = int(rest / 1000)
        ord += 1
    if num < 0:
        name.append(minus)
    name.reverse()
    return ' '.join(name).strip()


def decimal2text(value, places=2,
                 int_units=(('', '', ''), 'm'),
                 exp_units=(('', '', ''), 'm')):
    value = decimal.Decimal(value)
    q = decimal.Decimal(10) ** -places

    integral, exp = str(value.quantize(q)).split('.')
    return u'{} {}'.format(
        num2text(int(integral), int_units),
        num2text(int(exp), exp_units))


class TTransformer:
    def __init__(self):
        self.latin_d = {
            'A': 'А',
            'B': 'БИ',
            'C': 'СИ',
            'D': 'ДИ',
            'E': 'И',
            'F': 'ЭФ',
            'G': 'ДЖИ',
            'H': 'ЭЙЧ',
            'I': 'АЙ',
            'J': 'ДЖЕЙ',
            'K': 'КЕЙ',
            'L': 'ЭЛ',
            'M': 'ЭМ',
            'N': 'ЭН',
            'O': 'ОУ',
            'P': 'ПЭ',
            'Q': 'КЬЮ',
            'R': 'АР',
            'S': 'ЭС',
            'T': 'ТЭ',
            'U': 'УУ',
            'V': 'ВЭ',
            'W': 'ДАБЛВЭ',
            'X': 'ЭКС',
            'Y': 'ВАЙ',
            'Z': 'ЗЭТ',
        }
        self.russian_d = {
            'А': 'А',
            'Б': 'БЭ',
            'В': 'ВЭ',
            'Г': 'ГЭ',
            'Д': 'ДЭ',
            'Е': 'Е',
            'Ё': 'ЙО',
            'Ж': 'ЖЭ',
            'З': 'ЗЭ',
            'И': 'И',
            'Й': 'Й',
            'К': 'КЭ',
            'Л': 'ЭЛ',
            'М': 'ЭМ',
            'Н': 'ЭН',
            'О': 'О',
            'П': 'ПЭ',
            'Р': 'ЭР',
            'С': 'ЭС',
            'Т': 'ТЭ',
            'У': 'У',
            'Ф': 'ЭФ',
            'Х': 'ХЭ',
            'Ц': 'ЦЕ',
            'Ч': 'ЧЭ',
            'Ш': 'ШЭ',
            'Щ': 'ЩА',
            'Ъ': 'Ы',
            'Ы': 'Ы',
            'Ь': 'Ы',
            'Э': 'Э',
            'Ю': 'Ю',
            'Я': 'Я',

        }

    @staticmethod
    def numbers_to_text(text: str) -> str:
        r = r'\d+'
        s = re.sub(r, lambda x: ' ' + num2text(int(x.group())) + ' ', text)
        return s

    def latin_to_text(self, text: str) -> str:
        r = r'\b[A-Z]{1,}\b'
        s = '<prosody rate="slow">' + re.sub(r, lambda x: ' '.join([' ' + self.latin_d[i] + ' ' for i in x.group()]),
                                             text)
        return s + '</prosody>'

    def abbr_to_text(self, text: str) -> str:
        r = r'\b[А-Я]{1,}\b'
        s = '<prosody rate="slow">' + re.sub(r, lambda x: ' '.join(
            [' ' + self.russian_d[i] + ' ' for i in x.group()]), text)
        return s + '</prosody>'

    def zapyat_to_pause(self, text: str) -> str:
        text = text.replace('.', f'<break time="{np.random.randint(500, 700)}ms"/>')
        text = text.replace(',', f'<break time="{np.random.randint(200, 500)}ms"/>')
        text = text.replace('!', f'<break time="{np.random.randint(500, 700)}ms"/>')
        text = text.replace('?', f'<break time="{np.random.randint(500, 700)}ms"/>')
        return text


def create_db():
    path = "C:/projects/other/hackaton/code_sanya/rzd_voice_assistant/data/documents/"
    filenames = os.listdir()
    data = [pd.read_csv(f, encoding='utf-8') for f in filenames if f.endswith('csv')]


class TTS:
    def __init__(self, device: Union[str, torch.device]):
        self.model, _ = torch.hub.load(
            repo_or_dir='snakers4/silero-models',
            model='silero_tts',
            language='ru',
            speaker='v4_ru',
        )
        self.model.to(torch.device(device))
        self.device = device
        self.sample_rate = 24000
        self.t = TTransformer()

    def preprocess_text(self, text: str) -> str:
        text = self.t.numbers_to_text(text)
        text = self.t.latin_to_text(text)
        text = self.t.abbr_to_text(text)
        text = self.t.zapyat_to_pause(text)
        return text

    def get_speech(self, text: str, speaker: str = 'kseniya'):
        text = self.preprocess_text(text)
        text = '<speak>\n' + text + '\n</speak>'

        audio = self.model.apply_tts(
            ssml_text=text,
            speaker=speaker,
            sample_rate=self.sample_rate,
        )

        return audio


if __name__ == '__main__':
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    tts = TTS(device)

    text = """
    медленно 
    Q125 А
    D123
    ПВА
    QQ33
    74ЕВЭЛ3.
    QQ S EPTA PES
    """
    text = """"Осмотреть - АВУ, 1АТ, 2АТ, РУ2, РВД, контакты реверсора ""Вперёд"" - ""Назад."""""

    audio = tts.get_speech(text)
    print(audio)
    sf.write('data/output_audio_examples/examples_1.wav', audio.numpy(), samplerate=tts.sample_rate)
