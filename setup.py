from setuptools import setup, find_packages

__version__ = "2.1.0"


setup(
    name="pathfinder.vim",
    version=__version__,
    author="Daniel Thwaites",
    author_email="danthwaites30@btinternet.com",
    url="https://github.com/AlphaMycelium/pathfinder.vim",
    packages=find_packages(exclude=('tests',)),
)
