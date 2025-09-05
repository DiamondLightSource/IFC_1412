# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Path setup --------------------------------------------------------------

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
#
# import os
# import sys
# sys.path.insert(0, os.path.abspath('.'))


# -- Project information -----------------------------------------------------

project = 'GDDR6 Memory Controller'
copyright = '2025, Michael Abbott'
author = 'Michael Abbott'


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named 'sphinx.ext.*') or your custom
# ones.
extensions = [
    'sphinxcontrib.wavedrom',
]

# Add any paths that contain templates here, relative to this directory.
templates_path = ['_templates']

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = []

# Common links that should be available on every page
rst_epilog = '''
.. _Diamond Light Source:
    http://www.diamond.ac.uk
'''


# Wavedrom configuration for offline mode.  These two files were downloaded from
# https://wavedrom.com/skins/default.js and https://wavedrom.com/wavedrom.min.js
# respectively
offline_skin_js_path = '_static/wavedrom.default.js'
offline_wavedrom_js_path = '_static/wavedrom.min.js'


# -- Options for HTML output -------------------------------------------------

# The theme to use for HTML and HTML Help pages.  See the documentation for
# a list of builtin themes.
#
html_theme = 'sphinx_rtd_theme'

# If true, "Created using Sphinx" is shown in the HTML footer. Default is True.
html_show_sphinx = False

# If true, "(C) Copyright ..." is shown in the HTML footer. Default is True.
html_show_copyright = False


# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ['_static']
html_css_files = ['overrides.css']
# html_static_path = []

# # -- Options for LaTeX output -------------------------------------------------
# 
# # This is needed to allow TeX to see wavedrom images
# wavedrom_html_jsinline = False
# 
# 
# latex_elements = {
#     'papersize': 'a4paper',
#     'pointsize': '11pt',
#     'extraclassoptions': 'openany',
# }
