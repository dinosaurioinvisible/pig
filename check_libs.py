#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import importlib.util
import subprocess
import sys


def check_dependencies():
    # required packages for pig: install name : import name
    pig_packages = {"numpy":"numpy", "scipy":"scipy", "matplotlib":"matplotlib", "pandas":"pandas",
        "tifffile":"tifffile", "scikit-image":"skimage", "opencv-python":"cv2", "bokeh":"bokeh"}
    missingLibs = []
    # install name is the one you use for pip install etc
    ## import name is the one here
    for install_name, import_name in pig_packages.items():
        if importlib.util.find_spec(import_name) is None:
            missingLibs.append(install_name)

    if len(missingLibs) > 0:
        print("\nSome libraries are missing:")
        for package in missingLibs:
            print(f"\t- {package}")            
        # try to print-install libraries
        command = [sys.executable, "-m", "pip", "install", *missingLibs]
        print("\nTrying to auto-install the missing libraries...\n")
        try:
            subprocess.check_call(command)
        except subprocess.CalledProcessError as error:
            print(f"Could not install the required libraries: {error}")
            sys.exit(1)
            

check_dependencies()