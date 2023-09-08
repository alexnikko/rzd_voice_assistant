import torch
import pandas as pd
from sentence_transformers import SentenceTransformer


class InformationRetrieval:
    """class for text2text similarity"""
    def __init__(self, model_name_or_path: str, path_to_documents_database: str,
                 device: str = 'cpu', batch_size: int = 32,
                 topic_coeff: float = 1., malfunction_coeff: float = 0.8, cause_coeff: float = 0.2):
        # NLP embedder and hyperparameters for encoding (batch_size and device)
        self.embedder = SentenceTransformer(model_name_or_path, device=device)
        self.device = device
        self.batch_size = batch_size

        # hyperparameters for creating question embedding via concatenation
        self.topic_coeff = topic_coeff
        self.malfunction_coeff = malfunction_coeff
        self.cause_coeff = cause_coeff

        # initialize table with items and embeddings for search
        self.df = pd.read_csv(path_to_documents_database)
        self.database = self._create_database()

    def search(self, query: str) -> str:
        """search in index and return top-1 answer by most similar question"""
        query_emb = self.get_embeddings([query])
        cos_sims = torch.cosine_similarity(query_emb, self.database)
        idx = torch.topk(cos_sims, k=1).indices.item()
        item = self.df.iloc[idx]
        elimination = item.loc['elimination']
        return elimination

    def get_embeddings(self, texts: list[str]) -> torch.Tensor:
        return self.embedder.encode(texts, batch_size=self.batch_size, convert_to_tensor=True, device=self.device).cpu()

    def _create_database(self) -> torch.Tensor:
        """create index contains (docs) embeddings"""
        topic_embs = self.get_embeddings(self.df['topic'].tolist())
        malfunction_embs = self.get_embeddings(self.df['malfunction'].tolist())
        cause_embs = self.get_embeddings(self.df['cause'].tolist())
        return self.topic_coeff * topic_embs + self.malfunction_coeff * malfunction_embs + self.cause_coeff * cause_embs


if __name__ == '__main__':
    ir = InformationRetrieval(model_name_or_path='d0rj/ruRoberta-distilled',
                              path_to_documents_database='documents/appendix_1.csv')
    query = 'маслопрокачивающий насос не работает. КМН не включается'
    answer = ir.search(query)
    print(answer)
