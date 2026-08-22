"""Ejecuta el notebook en proceso y persiste sus salidas enriquecidas."""

import os
import sys
from pathlib import Path

os.environ.setdefault("MPLBACKEND", "Agg")

import nbformat
from IPython.core.interactiveshell import InteractiveShell
from IPython.utils.capture import capture_output


ROOT = Path(__file__).resolve().parents[1]
NOTEBOOK_PATH = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "09_modelos_deep_learning_top25.ipynb")


def to_notebook_output(output):
    return nbformat.v4.new_output(
        "display_data",
        data=dict(output.data),
        metadata=dict(output.metadata or {}),
    )


os.chdir(ROOT)
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
notebook = nbformat.read(NOTEBOOK_PATH, as_version=4)
shell = InteractiveShell.instance()
execution_count = 0

try:
    for cell_index, cell in enumerate(notebook.cells):
        if cell.cell_type != "code":
            continue

        execution_count += 1
        cell.execution_count = execution_count
        cell.outputs = []
        first_line = cell.source.strip().splitlines()[0] if cell.source.strip() else "Celda vacía"
        print(f"CELDA {cell_index + 1}: {first_line[:90]}", flush=True)

        with capture_output(stdout=True, stderr=True, display=True) as captured:
            result = shell.run_cell(cell.source, store_history=False)

        if captured.stdout:
            cell.outputs.append(nbformat.v4.new_output("stream", name="stdout", text=captured.stdout))
        if captured.stderr:
            cell.outputs.append(nbformat.v4.new_output("stream", name="stderr", text=captured.stderr))
        cell.outputs.extend(to_notebook_output(output) for output in captured.outputs)

        if result.error_before_exec is not None:
            raise result.error_before_exec
        if result.error_in_exec is not None:
            raise result.error_in_exec

        print(f"CELDA {cell_index + 1}: OK", flush=True)
finally:
    nbformat.write(notebook, NOTEBOOK_PATH)

print(f"NOTEBOOK_EXECUTED={NOTEBOOK_PATH}", flush=True)
