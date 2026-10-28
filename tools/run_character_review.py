"""Launch the isolated Godot character review with existing tools and exports."""
import subprocess
from prepare_characters import prepare
from godot_runtime import ROOT, find_godot, import_project

if __name__=='__main__':
    prepare();binary=find_godot()
    import_project(binary, ROOT/'godot')
    raise SystemExit(subprocess.call([binary,'--path',str(ROOT/'godot'),'res://CharacterReview.tscn']))
