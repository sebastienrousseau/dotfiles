# Python Aliases

Manage Python aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `python.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. When `DOTFILES_ALIAS_ECOSYSTEMS` is set to something other than `all`, it is included only if that value contains `python`.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `uva` | `uv add` | Only when `uv` is on PATH. |
| `uvc` | `uv pip compile` | Only when `uv` is on PATH. |
| `uvi` | `uv init` | Only when `uv` is on PATH. |
| `uvl` | `uv lock` | Only when `uv` is on PATH. |
| `uvp` | `uv pip` | Only when `uv` is on PATH. |
| `uvpi` | `uv pip install` | Only when `uv` is on PATH. |
| `uvra` | `uv run --all` | Only when `uv` is on PATH. |
| `uvr` | `uv run` | Only when `uv` is on PATH. |
| `uvsa` | `source .venv/bin/activate` | Only when `uv` is on PATH. |
| `uvs` | `uv sync` | Only when `uv` is on PATH. |
| `uvt` | `uv tree` | Only when `uv` is on PATH. |
| `uvv` | `uv venv` | Only when `uv` is on PATH. |
| `pip` | function | Only when `python3` is on PATH. |
| `py` | `python` | Quick Python access. Only when `python3` is on PATH. |
| `ipy` | `ipython` | Interactive Python shell. Only when `python3` is on PATH. |
| `pyv` | `python --version` | Show Python version. Only when `python3` is on PATH. |
| `pydoc` | `python -m pydoc` | Python documentation. Only when `python3` is on PATH. |
| `pipi` | `pip install` | Install packages. Only when `python3` is on PATH. |
| `pipl` | `pip list` | List installed packages. Only when `python3` is on PATH. |
| `pipup` | `pip install --upgrade` | Upgrade packages. Only when `python3` is on PATH. |
| `pipun` | `pip uninstall -y` | Uninstall packages. Only when `python3` is on PATH. |
| `pipf` | `pip freeze` | Show frozen requirements. Only when `python3` is on PATH. |
| `pipr` | `pip install -r` | Install from requirements. Only when `python3` is on PATH. |
| `pipout` | `pip freeze > requirements.txt` | Save requirements. Only when `python3` is on PATH. |
| `pep8` | `autopep8` | Code formatting. Only when `python3` is on PATH. |
| `lint` | `pylint` | Code linting. Only when `python3` is on PATH. |
| `black` | `python -m black` | Code formatting with black. Only when `python3` is on PATH. |
| `mypy` | `python -m mypy` | Static type checking. Only when `python3` is on PATH. |
| `ruff` | `python -m ruff` | Fast Python linter. Only when `python3` is on PATH. |
| `rf` | `ruff check --fix` | Ruff auto-fix lint pass. Only when `python3` is on PATH. |
| `rfmt` | `ruff format` | Ruff formatter. Only when `python3` is on PATH. |
| `pytest` | `python -m pytest` | Run tests. Only when `python3` is on PATH. |
| `pytestv` | `pytest -v` | Verbose test output. Only when `python3` is on PATH. |
| `pytestc` | `pytest --cov` | Test coverage. Only when `python3` is on PATH. |
| `unittest` | `python -m unittest` | Run unittest. Only when `python3` is on PATH. |
| `venv` | `python -m venv` | Create virtual environment. Only when `python3` is on PATH. |
| `mkvenv` | `python -m venv .venv` | Create .venv in current directory. Only when `python3` is on PATH. |
| `mkvenvlocal` | `python -m venv ./venv` | Create ./venv in current directory. Only when `python3` is on PATH. |
| `venva` | `source ./.venv/bin/activate` | Activate .venv. Only when `python3` is on PATH. |
| `venvlocal` | `source ./venv/bin/activate` | Activate ./venv. Only when `python3` is on PATH. |
| `deact` | `deactivate` | Deactivate venv. Only when `python3` is on PATH. |
| `rmvenv` | `rm -rf ./venv` | Remove venv. Only when `python3` is on PATH. |
| `rmpyc` | `find . -type f -name '*.pyc' -delete` | Remove .pyc files. Only when `python3` is on PATH. |
| `rmpyo` | `find . -type f -name '*.pyo' -delete` | Remove .pyo files. Only when `python3` is on PATH. |
| `rmpyall` | `find . -type f -name '*.py[cod]' -delete && find . -type d -name __pycache__ -delete` | Remove all. Only when `python3` is on PATH. |
| `python_speed` | function | Only when `python3` is on PATH. |
| `python_profile` | function | Only when `python3` is on PATH. |
| `python_debug` | function | Only when `python3` is on PATH. |
| `python_serve` | function | Only when `python3` is on PATH. |
| `python_new_project` | function | Only when `python3` is on PATH. |
| `python_info` | function | Only when `python3` is on PATH. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
