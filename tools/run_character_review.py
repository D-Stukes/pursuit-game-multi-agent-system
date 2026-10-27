"""Launch the isolated Godot character review with existing tools and exports."""
import subprocess
from prepare_characters import prepare
from run_playtest import ROOT,find_godot

if __name__=='__main__':
    prepare();binary=find_godot()
    subprocess.run([binary,'--headless','--editor','--path',str(ROOT/'godot'),'--import'],check=True)
    raise SystemExit(subprocess.call([binary,'--path',str(ROOT/'godot'),'res://CharacterReview.tscn']))
