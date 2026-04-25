from typing import List

import numpy as np
import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel
from sklearn.decomposition import TruncatedSVD


class RecommendRequest(BaseModel):
    userId: int
    topN: int = 10


class RecommendationItem(BaseModel):
    movieId: int
    score: float
    reason: str


class RecommendResponse(BaseModel):
    userId: int
    recommendations: List[RecommendationItem]


app = FastAPI(title="WHU Recommendation Algorithm Service")


def _build_sample_data() -> pd.DataFrame:
    # 占位数据用于演示完整算法链路，可替换为MySQL读取结果。
    return pd.DataFrame(
        [
            (1, 1, 4.5), (1, 2, 5.0), (1, 3, 2.0),
            (2, 1, 4.0), (2, 2, 4.5), (2, 4, 4.0),
            (3, 2, 4.0), (3, 3, 4.5), (3, 5, 5.0),
            (4, 1, 3.5), (4, 4, 4.5), (4, 5, 4.0),
            (5, 2, 3.0), (5, 3, 4.0), (5, 6, 4.5),
        ],
        columns=["user_id", "movie_id", "rating"],
    )


def _hybrid_recommend(user_id: int, top_n: int) -> List[RecommendationItem]:
    ratings = _build_sample_data()
    matrix = ratings.pivot_table(index="user_id", columns="movie_id", values="rating").fillna(0.0)
    if user_id not in matrix.index:
        # 冷启动用户默认返回热门项
        popular = ratings.groupby("movie_id")["rating"].mean().sort_values(ascending=False).head(top_n)
        return [
            RecommendationItem(
                movieId=int(movie_id),
                score=float(score),
                reason="新用户默认按全站高评分电影推荐",
            )
            for movie_id, score in popular.items()
        ]

    # Step 1: user-based CF Pearson 相似度召回
    user_vector = matrix.loc[user_id]
    similarities = matrix.corrwith(user_vector, axis=1).fillna(0.0).drop(labels=[user_id], errors="ignore")
    top_neighbors = similarities.sort_values(ascending=False).head(20).index.tolist()

    seen_movies = set(ratings[ratings["user_id"] == user_id]["movie_id"].tolist())
    neighbor_movies = ratings[ratings["user_id"].isin(top_neighbors)]["movie_id"].unique().tolist()
    candidates = [m for m in neighbor_movies if m not in seen_movies]
    if not candidates:
        candidates = [m for m in matrix.columns.tolist() if m not in seen_movies]

    # Step 2: SVD 排序
    n_components = min(3, len(matrix.columns) - 1) if len(matrix.columns) > 1 else 1
    svd = TruncatedSVD(n_components=max(1, n_components), random_state=42)
    user_latent = svd.fit_transform(matrix.values)
    item_latent = svd.components_.T

    user_index = list(matrix.index).index(user_id)
    base_bias = ratings.groupby("movie_id")["rating"].mean().to_dict()
    results = []
    for movie_id in candidates:
        movie_index = list(matrix.columns).index(movie_id)
        score = float(np.dot(user_latent[user_index], item_latent[movie_index])) + float(base_bias.get(movie_id, 0.0))
        results.append(
            RecommendationItem(
                movieId=int(movie_id),
                score=score,
                reason="基于相似用户偏好与矩阵分解隐语义特征生成",
            )
        )

    results.sort(key=lambda x: x.score, reverse=True)
    return results[:top_n]


@app.get("/api/python/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/python/calculate", response_model=RecommendResponse)
def calculate(payload: RecommendRequest) -> RecommendResponse:
    recommendations = _hybrid_recommend(payload.userId, payload.topN)
    return RecommendResponse(userId=payload.userId, recommendations=recommendations)
