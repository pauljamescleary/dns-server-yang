MODULES = dns-server dns-parameters dnssec-signing tsig-algorithms \
	  dnssec-algorithms knot-dns
DATE ?= $(shell date +%F)
EXAMPLE_BASE = example
EXAMPLE_TYPE = data
baty = $(EXAMPLE_BASE)-$(EXAMPLE_TYPE)
EXAMPLE_INST = $(baty).xml
PYANG_OPTS = --lax-quote-checks

# Paths for pyang
export PYANG_RNG_LIBDIR ?= /usr/share/yang/schema
export PYANG_XSLT_DIR ?= /usr/share/yang/xslt
export YANG_MODPATH ?= .:/usr/share/yang/modules/ietf:/usr/share/yang/modules/iana
yams = $(addsuffix .yang, $(MODULES))
xsldir = ../yangson/tools/xslt
yypars = --stringparam date $(DATE)
schemas = $(baty).rng $(baty).sch $(baty).dsrl
y2dopts = -t $(EXAMPLE_TYPE) -b $(EXAMPLE_BASE)

.PHONY: all clean commit json knot nsd rnc schema validate yang

all: hello.xml
	@pyang --lint -L $<

json: $(baty).json

schema: $(schemas)

yang: $(yams)

knot: knot.conf

nsd: nsd.conf

hello.xml: $(yams) hello-external.ent
	@echo '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">' > $@
	@echo '<capabilities>' >> $@
	@echo '<capability>urn:ietf:params:netconf:base:1.1</capability>' >> $@
	@for m in $(yams); do \
	  capa=$$(pyang $(PYANG_OPTS) -f capability --capability-entity $$m); \
	  if [ "$$capa" != "" ]; then \
	    echo "<capability>$$capa</capability>" >> $@; \
	  fi \
	done
	@cat hello-external.ent >> $@
	@echo '</capabilities>' >> $@
	@echo '</hello>' >> $@

%.yang: %.yinx
	@xsltproc --xinclude $(xsldir)/canonicalize.xsl $< | \
	  xsltproc --output $@ $(yypars) $(xsldir)/yin2yang.xsl -

$(schemas): hello.xml
	@yang2dsdl $(y2dopts) -L $<

%.rnc: %.rng
	@trang -I rng -O rnc $< $@

rnc: $(baty).rnc

validate: $(EXAMPLE_INST) $(schemas)
	@yang2dsdl -j -s $(y2dopts) -v $<

$(baty).json: model.xsl $(EXAMPLE_INST)
	@xsltproc --output $@ $^

knot.conf: xslt/knot.xsl $(EXAMPLE_INST)
	@xsltproc --output $@ $^

nsd.conf: xslt/nsd.xsl $(EXAMPLE_INST)
	@xsltproc --output $@ $^

model.xsl: hello.xml
	@pyang -o $@ -f jsonxsl -L $<

model.tree: hello.xml
	@pyang $(PYANG_OPTS) -f tree -o $@ -L $<

commit: model.tree $(baty).json
	@git add $^ $(yams)
	@git commit

clean:
	@rm -rf *.rng *.rnc *.sch *.dsrl hello.xml model.tree \
	knot.conf $(yams)
