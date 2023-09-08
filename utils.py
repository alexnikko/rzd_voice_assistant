import pandas as pd
import os

from docx import Document
from docx.table import Table
from collections import defaultdict
from tqdm.auto import tqdm


def read_document(document_path: str) -> Document:
    return Document(document_path)


def create_df_from_doc_table(doc_table: Table) -> pd.DataFrame:
    df = [['' for _ in range(len(doc_table.columns))] for _ in range(len(doc_table.rows))]
    for i, row in enumerate(doc_table.rows):
        for j, cell in enumerate(row.cells):
            if cell.text:
                df[i][j] = cell.text
    return pd.DataFrame(df)


def format_df(df: pd.DataFrame) -> pd.DataFrame:
    data = defaultdict(list)
    topic = None
    for idx, row in enumerate(df.itertuples()):
        if idx == 0:
            continue
        if row._1 == row._2 == row._3 == row._4:
            topic = row._1
            continue
        data['N'].append(row._1)
        data['topic'].append(topic)
        data['malfunction'].append(row._2)
        data['cause'].append(row._3)
        data['elimination'].append(row._4)
    df = pd.DataFrame(data)
    for col in df:
        if any(df[col] != df[col].str.strip()):
            df[col] = df[col].str.strip()
    assert all(~df.isna()), 'Some cells in DataFrame are NaNs'
    return df


def prepare_dataframes(document_path: str):
    document = read_document(document_path)
    dfs = [create_df_from_doc_table(doc_table) for doc_table in tqdm(document.tables)]
    dfs.pop(0)
    for idx, df in enumerate(dfs, start=1):
        save_path = os.path.join('documents', f'appendix_{idx}.csv')
        formatted_df = format_df(df)
        formatted_df.to_csv(save_path, index=False)


if __name__ == '__main__':
    prepare_dataframes('documents/train.docx')
