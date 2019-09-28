zipfilename := "little-things-gb.zip"
binaries := \
  ca83/ca83.gb \
  firstwhite/firstwhite.gb \
  tellinglys/tellinglys.gb \
  gbpng/gbpng.gb.png

.PHONY: all clean dist zip zip.in $(binaries)

all: $(binaries)

$(binaries):
	$(MAKE) -C $(dir $@) $(notdir $@)

clean:
	for d in $(foreach o,$(binaries),$(dir $(o))); do \
	  $(MAKE) -C $$d clean; \
	done

dist: $(zipfilename)

$(zipfilename): $(binaries) zip.in
	zip -9u $@ -@ < zip.in

zip.in:
	git ls-files | grep -e "^[^\.]" > zip.in
	echo zip.in >> zip.in
	for d in $(binaries); do echo $$d >> zip.in; done
