""" This script runs pylint and bandit for all .py files in /lambdas directory """
import os
import glob
import subprocess

FOLDER_PATH = '/'  
PYLINT_DISABLE = [
    'C0301', # Line too long
    'C0103', # Invalid name of module
    'C0114', # Missing module docstring
    'C0116', # Missing function or method docstring
    'W1203', # Use lazy % formatting in logging functions (logging-fstring-interpolation)
    'W1201', # Use lazy % formatting in logging functions (logging-not-lazy)
]
BANDIT_SKIP = [
    'B101', # Assert
    'B108', # Hardcoded_tmp_directory
]

def pylint(filename):
    """ call pylint """
    try:
        res = subprocess.check_output(
            f'pylint {filename} --disable {",".join(PYLINT_DISABLE)}'.split(),
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        return res
    except subprocess.CalledProcessError as exc:
        return exc.stdout

def bandit(filename):
    """ call bandit """
    try:
        res = subprocess.check_output(
            f'bandit {filename} --skip {",".join(BANDIT_SKIP)}'.split(),
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
        if 'No issues identified.' in str(res):
            return 'Bandit: No issues identified.' # skip verbose
        return res
    except subprocess.CalledProcessError as exc:
        return exc.stdout

def tab(text, indent="\t"):
    """ returns text with a tab """
    return '\n'.join([indent + line for line in text.splitlines()])

def main():
    """ run pylint and bandit for all python files """
    file_list = glob.glob(os.path.join(FOLDER_PATH, "*/*.py"))
    file_list = [f for f in file_list if 'utils' not in f]
    file_list.sort()
    
    if not file_list:
        print("No Python files found in /lambdas subdirectories")
        return

    print("Analyzing Python files:")
    for filename in file_list:
        print(f"\nAnalyzing: {filename}")
        print("Pylint results:")
        print(tab(pylint(filename)))
        print("Bandit results:")
        print(tab(bandit(filename)))

if __name__ == '__main__':
    main()