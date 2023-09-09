import torch
import pandas as pd
from typing import Union

from sentence_transformers import SentenceTransformer


class Embedder:
    def __init__(self, model_name_or_path: str,
                 device: Union[str, torch.device] = 'cpu', batch_size: int = 32,
                 ):
        # NLP embedder and hyperparameters for encoding (batch_size and device)
        self.embedder = SentenceTransformer(model_name_or_path, device=device)
        self.device = device
        self.batch_size = batch_size

    def get_embeddings(self, texts: list[str]) -> torch.Tensor:
        return self.embedder.encode(texts, batch_size=self.batch_size, convert_to_tensor=True, device=self.device).cpu()


class Database:
    def __init__(self, path_to_documents_database: str,
                 topic_coeff: float = 1., malfunction_coeff: float = 0.8, cause_coeff: float = 0.2,
                 embedder: Embedder = None):
        # hyperparameters for creating question embedding via concatenation
        self.topic_coeff = topic_coeff
        self.malfunction_coeff = malfunction_coeff
        self.cause_coeff = cause_coeff

        # initialize table with items and embeddings for search
        self.df = pd.read_csv(path_to_documents_database)
        self.database = None
        self.embedder = embedder

    def _get_or_set_embedder(self, embedder: Embedder):
        if self.embedder is None:
            if embedder is not None:
                return embedder
            else:
                assert False, 'No embedder passed at any time'
        else:
            return self.embedder

    def search(self, query: str, embedder: Embedder = None, k: int = 5) -> pd.DataFrame:
        """search in index and return top-1 answer by most similar question"""
        embedder = self._get_or_set_embedder(embedder)
        query_emb = embedder.get_embeddings([query])
        cos_sims = torch.cosine_similarity(query_emb, self.database)
        idx = torch.topk(cos_sims, k=k).indices.numpy()
        item = self.df.iloc[idx]
        item['cos_sim'] = cos_sims[idx]
        elimination = item
        return elimination

    def init_database(self, embedder: Embedder = None) -> None:
        """create index contains (docs) embeddings"""
        embedder = self._get_or_set_embedder(embedder)
        topic_embs = embedder.get_embeddings(self.df['topic'].tolist())
        malfunction_embs = embedder.get_embeddings(self.df['malfunction'].tolist())
        cause_embs = embedder.get_embeddings(self.df['cause'].tolist())
        self.database = self.topic_coeff * topic_embs + self.malfunction_coeff * malfunction_embs + self.cause_coeff * cause_embs


if __name__ == '__main__':
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    emb = Embedder(model_name_or_path='d0rj/ruRoberta-distilled', device=device)

    db = Database(path_to_documents_database='data/documents/appendix_1.csv', embedder=emb)
    db.init_database()

    query = 'насос не работает'
    answer = db.search(query)
    print(answer)
