#!/usr/bin/env python3
"""Create real (tiny) model artifacts for the three SageMaker endpoints.

    fraud            -> XGBoost 1.5 model, built locally (no AWS calls)
    forecasting      -> Linear Learner, trained with a small SageMaker training job
    recommendations  -> Factorization Machines, trained with a small SageMaker training job

Output (what terraform/s3.tf uploads):
    terraform/models/<team>/model.tar.gz

Setup:
    pip install "xgboost==1.5.2" "sagemaker<3" boto3 numpy
    export AWS_DEFAULT_REGION=us-east-1

Usage (run from the repo root):
    python make_model_artifacts.py --bucket <model-artifacts-bucket> --role <sagemaker-execution-role-arn>
    python make_model_artifacts.py --teams fraud          # XGBoost only, no AWS needed

The two training jobs run on ml.m5.large for a few minutes and cost pennies.
The training scratch data/output goes under s3://<bucket>/training/.
"""
import argparse
import os
import sys
import tarfile
import tempfile
from urllib.parse import urlparse

import numpy as np

ALL_TEAMS = ["fraud", "recommendations", "forecasting"]


def pack(src_file, arcname, dest):
    """Write a .tar.gz with a single file at the archive root."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with tarfile.open(dest, "w:gz") as tar:
        tar.add(src_file, arcname=arcname)
    print(f"  wrote {dest} ({os.path.getsize(dest)} bytes)")


def make_fraud(out_dir):
    """XGBoost model in the format the sagemaker-xgboost:1.5-1 container loads."""
    import xgboost as xgb

    if not xgb.__version__.startswith("1.5"):
        sys.exit(
            f"xgboost {xgb.__version__} is installed, but the sagemaker-xgboost:1.5-1 "
            "container needs a model saved by 1.5.x. Run: pip install xgboost==1.5.2"
        )

    rng = np.random.default_rng(0)
    X = rng.random((500, 5))
    y = (X[:, 0] + X[:, 1] > 1.0).astype(int)
    booster = xgb.train(
        {"objective": "binary:logistic"}, xgb.DMatrix(X, label=y), num_boost_round=10
    )

    with tempfile.TemporaryDirectory() as tmp:
        model_file = os.path.join(tmp, "xgboost-model")
        booster.save_model(model_file)  # no .json/.ubj extension -> binary format
        pack(model_file, "xgboost-model", os.path.join(out_dir, "fraud", "model.tar.gz"))


def train_builtin(team, estimator, X, y, out_dir):
    """Run a small training job and download its model.tar.gz into out_dir/<team>/."""
    import boto3

    print(f"  training {team} ...")
    records = estimator.record_set(X, labels=y, channel="train")
    estimator.fit(records, mini_batch_size=100, wait=True, logs=False)

    uri = urlparse(estimator.model_data)  # s3://bucket/key/output/model.tar.gz
    dest = os.path.join(out_dir, team, "model.tar.gz")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    boto3.client("s3").download_file(uri.netloc, uri.path.lstrip("/"), dest)
    print(f"  wrote {dest} ({os.path.getsize(dest)} bytes)")


def make_forecasting(out_dir, bucket, role):
    from sagemaker import LinearLearner

    rng = np.random.default_rng(1)
    X = rng.random((1000, 10)).astype("float32")
    y = (X @ rng.random(10) + rng.normal(0, 0.05, 1000)).astype("float32")

    est = LinearLearner(
        role=role,
        instance_count=1,
        instance_type="ml.m5.large",
        predictor_type="regressor",
        data_location=f"s3://{bucket}/training/forecasting/data/",
        output_path=f"s3://{bucket}/training/forecasting/output/",
    )
    train_builtin("forecasting", est, X, y, out_dir)


def make_recommendations(out_dir, bucket, role):
    from sagemaker import FactorizationMachines

    rng = np.random.default_rng(2)
    X = rng.random((1000, 10)).astype("float32")
    y = (X[:, 0] * 2.0 + X[:, 1] + rng.normal(0, 0.05, 1000)).astype("float32")

    est = FactorizationMachines(
        role=role,
        instance_count=1,
        instance_type="ml.m5.large",
        num_factors=8,
        predictor_type="regressor",
        data_location=f"s3://{bucket}/training/recommendations/data/",
        output_path=f"s3://{bucket}/training/recommendations/output/",
    )
    train_builtin("recommendations", est, X, y, out_dir)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--teams", nargs="+", choices=ALL_TEAMS, default=ALL_TEAMS)
    p.add_argument("--out", default="terraform/models", help="output root (default: terraform/models)")
    p.add_argument("--bucket", help="S3 bucket for training scratch data/output (needed for recommendations/forecasting)")
    p.add_argument("--role", help="SageMaker execution role ARN used by the training jobs")
    args = p.parse_args()

    needs_aws = {"recommendations", "forecasting"} & set(args.teams)
    if needs_aws and not (args.bucket and args.role):
        p.error("--bucket and --role are required for the recommendations and forecasting teams")

    if "fraud" in args.teams:
        print("fraud (XGBoost 1.5)")
        make_fraud(args.out)
    if "forecasting" in args.teams:
        print("forecasting (Linear Learner)")
        make_forecasting(args.out, args.bucket, args.role)
    if "recommendations" in args.teams:
        print("recommendations (Factorization Machines)")
        make_recommendations(args.out, args.bucket, args.role)

    print("\nDone. Commit the tarballs, then let Terraform upload them.")


if __name__ == "__main__":
    main()