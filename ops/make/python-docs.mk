PYTHON_DOCS_DIR ?= docs
PYTHON_DOCS_PACKAGES += sphinx sphinxcontrib-napoleon sphinx-copybutton
PYTHON_DOCS_PACKAGES += sphinxcontrib-makedomain insegel python-docs-theme sphinx-material
PYTHON_DOCS_LIBS=.lib/python/docs
SPHINXBUILD=$(PYTHON) -c "from sphinx.cmd.build import main; main()"
export
ifneq ($(wildcard $(PYTHON_DOCS_DIR)/requirements.txt),)
DEPSCHECKSUMFILES += $(PYTHON_DOCS_DIR)/requirements.txt
endif

cmd.doc8 = $(PYTHON) -c "from doc8.main import main; main()"
cmd.lint-docs = $(cmd.doc8) $(PYTHON_DOCS_DIR)
cmd.sphinx-quickstart = $(PYTHON) -c "from sphinx.cmd.quickstart import main; main()"
gitlab.pip.packages += $(PYTHON_DOCS_PACKAGES)


$(PYTHON_DOCS_DIR)/Makefile: $(PYTHON_DOCS_DIR)/requirements.txt
	@$(cmd.sphinx-quickstart) $(PYTHON_DOCS_DIR)
	@$(cmd.git) add -f $(PYTHON_DOCS_DIR)/*


$(PYTHON_DOCS_DIR):
	@mkdir -p $(PYTHON_DOCS_DIR)


$(PYTHON_DOCS_LIBS):
	@$(PIP) install $(PYTHON_DOCS_PACKAGES) --target $(PYTHON_DOCS_LIBS)
ifneq ($(wildcard $(PYTHON_DOCS_DIR)/requirements.txt),)
	@$(PIP) install -r $(PYTHON_DOCS_DIR)/requirements.txt --target $(PYTHON_DOCS_LIBS)
endif


$(PYTHON_DOCS_DIR)/requirements.txt: $(PYTHON_DOCS_DIR) $(PYTHON_DOCS_LIBS)
	@$(PIP) freeze --path $(PYTHON_DOCS_LIBS)\
		> $(PYTHON_DOCS_DIR)/requirements.txt
	@$(cmd.git.add) $(PYTHON_DOCS_DIR)/requirements.txt


$(PYTHON_DOCS_DIR)/build/dirhtml: $(PYTHON_DOCS_DIR)
	@cd $(PYTHON_DOCS_DIR) && $(MAKE) dirhtml


build-python-docs:
	@$(MAKE) -C $(PYTHON_DOCS_DIR) dirhtml
	@mkdir -p $(HTML_DOCUMENT_ROOT)
	@cp -R $(PYTHON_DOCS_DIR)/build/dirhtml/* $(HTML_DOCUMENT_ROOT)/


bootstrap-python-docs: $(PYTHON_DOCS_DIR)/Makefile


configure-python-docs:
depsinstall: $(PYTHON_DOCS_LIBS)
public: build-python-docs
