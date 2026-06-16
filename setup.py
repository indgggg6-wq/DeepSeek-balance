"""
打包脚本 - 使用 py2app 将应用打包为独立 .app
运行方式: python3 setup.py py2app

如果还没安装 py2app: pip3 install --user py2app
"""

from setuptools import setup

APP = ['deepseek_balance.py']
DATA_FILES = [
    ('', ['config.json']),
]
OPTIONS = {
    'argv_emulation': False,
    'plist': {
        'LSUIElement': True,  # 不显示 Dock 图标，纯菜单栏应用
        'CFBundleName': 'DeepSeek 余额',
        'CFBundleDisplayName': 'DeepSeek 余额',
        'CFBundleIdentifier': 'com.deepseek.balance',
        'CFBundleVersion': '1.0.0',
        'CFBundleShortVersionString': '1.0',
        'NSHighResolutionCapable': True,
    },
    'packages': ['rumps', 'requests', 'matplotlib', 'sqlite3'],
    'includes': [
        'matplotlib.backends.backend_macosx',
        'objc', 'Foundation', 'AppKit',
    ],
    'excludes': [
        'tkinter', 'PyQt5', 'PySide2', 'wx',
    ],
    'site_packages': True,
}

setup(
    name='DeepSeekBalance',
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
)
