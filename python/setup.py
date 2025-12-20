"""
Setup configuration for DMS Migration Utilities
"""

from setuptools import setup, find_packages

with open("requirements.txt") as f:
    requirements = f.read().splitlines()

setup(
    name="dms-migration-utils",
    version="1.0.0",
    description="Utilities for AWS DMS cross-account, cross-region database migration",
    author="Data Engineering Team",
    author_email="data-team@example.com",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=requirements,
    python_requires=">=3.9",
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Database",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    entry_points={
        "console_scripts": [
            "dms-validate=scripts.pre_migration_check:main",
        ],
    },
)
