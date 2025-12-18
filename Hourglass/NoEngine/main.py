import os

for command in [
    "clang simulator.cpp -o simulator.exe -std=c++23 -O2",
    "simulator.exe",
    "render.py",
]:
    if os.system(command) != 0:
        break
