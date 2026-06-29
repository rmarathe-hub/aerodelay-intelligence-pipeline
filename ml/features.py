from __future__ import annotations

import math
from typing import Literal

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

FeatureSetName = Literal["schedule_only", "weather_only", "full"]

SCHEDULE_FEATURES = [
    "reporting_airline",
    "origin",
    "dest",
    "dep_hour_utc",
    "dep_dow",
    "dep_month",
    "dep_time_source",
]

WEATHER_FEATURES = [
    "wind_speed_knots",
    "wind_gust_knots",
    "precip_1hr_inches",
    "visibility_miles",
    "temperature_f",
    "relative_humidity_pct",
    "weather_obs_lag_minutes",
    "is_precip",
    "sin_hour",
    "cos_hour",
]

FEATURE_SETS: dict[FeatureSetName, list[str]] = {
    "schedule_only": SCHEDULE_FEATURES.copy(),
    "weather_only": ["origin", *WEATHER_FEATURES],
    "full": SCHEDULE_FEATURES + WEATHER_FEATURES,
}

NUMERIC_FEATURES = sorted(
    {
        *(
            f
            for f in FEATURE_SETS["full"]
            if f
            not in {
                "reporting_airline",
                "origin",
                "dest",
                "dep_time_source",
            }
        )
    }
)

CATEGORICAL_FEATURES = [
    "reporting_airline",
    "origin",
    "dest",
    "dep_time_source",
]


def add_derived_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    precip = out["precip_1hr_inches"].fillna(0)
    out["is_precip"] = (precip > 0).astype(int)
    hour_rad = 2 * math.pi * out["dep_hour_utc"].fillna(0) / 24.0
    out["sin_hour"] = np.sin(hour_rad)
    out["cos_hour"] = np.cos(hour_rad)
    return out


def feature_columns(name: FeatureSetName) -> list[str]:
    return FEATURE_SETS[name]


def split_xy(
    df: pd.DataFrame,
    feature_set: FeatureSetName,
    target_col: str = "target",
) -> tuple[pd.DataFrame, pd.Series]:
    cols = feature_columns(feature_set)
    x = df[cols]
    y = df[target_col].astype(int)
    return x, y


def build_preprocessor(feature_set: FeatureSetName) -> ColumnTransformer:
    cols = feature_columns(feature_set)
    numeric = [c for c in cols if c in NUMERIC_FEATURES]
    categorical = [c for c in cols if c in CATEGORICAL_FEATURES]
    transformers: list[tuple] = []
    if numeric:
        transformers.append(
            (
                "num",
                Pipeline(
                    [
                        ("imputer", SimpleImputer(strategy="median")),
                        ("scaler", StandardScaler()),
                    ]
                ),
                numeric,
            )
        )
    if categorical:
        transformers.append(
            (
                "cat",
                OneHotEncoder(handle_unknown="ignore", max_categories=30, sparse_output=False),
                categorical,
            )
        )
    return ColumnTransformer(transformers=transformers)


def build_logistic_pipeline(feature_set: FeatureSetName) -> Pipeline:
    return Pipeline(
        [
            ("prep", build_preprocessor(feature_set)),
            (
                "clf",
                LogisticRegression(
                    max_iter=300,
                    class_weight="balanced",
                    random_state=42,
                ),
            ),
        ]
    )


def build_hgb_pipeline(
    feature_set: FeatureSetName,
    params: dict | None = None,
) -> Pipeline:
    default_params = {
        "max_depth": 8,
        "learning_rate": 0.1,
        "max_iter": 200,
        "min_samples_leaf": 50,
        "l2_regularization": 1.0,
        "random_state": 42,
    }
    if params:
        default_params.update(params)
    return Pipeline(
        [
            ("prep", build_preprocessor(feature_set)),
            ("clf", HistGradientBoostingClassifier(**default_params)),
        ]
    )
