BLENDER       ?= blender
EXPORT_SCRIPT ?= blender-obj-export.py

OBJ_BLEND_FILES ?= \
	Squids/Squid1/squid1.blend \
	Squids/Squid2/squid2.blend \
	Skulls/Skull3/skull3.blend \
	Skulls/Skull4/skull4.blend \
	Skulls/Skull1/skull1.blend \
	Skulls/Skull2/skull2.blend

OBJ_FILES := $(OBJ_BLEND_FILES:.blend=.obj)

all: $(OBJ_FILES)
	@echo $(OBJ_FILES)

%.obj: %.blend $(EXPORT_SCRIPT)
	$(BLENDER) --background "$<" --python $(EXPORT_SCRIPT) -- "$@"
