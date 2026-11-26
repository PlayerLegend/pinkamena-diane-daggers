BLENDER       ?= blender
OBJ_EXPORT_SCRIPT ?= blender-obj-export.py
GLB_EXPORT_SCRIPT ?= blender-glb-export.py

PROJECT_NAME = 'DianeDaggers'

EXPORT_DIR = export/$(PROJECT_NAME)

EXPORT_WEB_TARGET = $(EXPORT_DIR)/Web/$(PROJECT_NAME).html

OBJ_BLEND_FILES ?= \
	Blood3D/Blood1.blend \
	Blood3D/Blood2.blend \
	Blood3D/Blood3.blend \
	Skulls/Skull1/skull1.blend \
	Skulls/Skull2/skull2.blend \
	Skulls/Skull3/skull3.blend \
	Skulls/Skull4/skull4.blend \
	Squids/Squid1/squid1.blend \
	Squids/Squid2/squid2.blend \

GLB_BLEND_FILES ?= \
	Centipede/Centipede1/CentipedeHead.blend \
	Centipede/Centipede1/CentipedeSegment.blend \
	PlayerController/Hoof.blend \
	Blend/PinkiePie/PinkiePie.blend

OBJ_FILES := $(OBJ_BLEND_FILES:.blend=.obj)
GLB_FILES := $(GLB_BLEND_FILES:.blend=.glb)

OTHER_GLB := \
	Centipede/Centipede1/CentipedeSegment.glb

test: Centipede/Centipede1/CentipedeSegment.glb
Centipede/Centipede1/CentipedeSegment.glb: Centipede/Centipede1/CentipedeSegment.blend
	blender -b "$<" --python blender-vat-glb-export.py -- "$@"

all: $(OBJ_FILES) $(GLB_FILES)
	@echo $(OBJ_FILES)

%.obj: %.blend $(EXPORT_SCRIPT)
	$(BLENDER) --background "$<" --python $(OBJ_EXPORT_SCRIPT) -- "$@"

%.glb: %.blend $(EXPORT_SCRIPT)
	$(BLENDER) --background "$<" --python $(GLB_EXPORT_SCRIPT) -- "$@"

web: build
	@mkdir -p $(dir $(EXPORT_WEB_TARGET))
	godot --headless --export-release "Web" $(EXPORT_WEB_TARGET)

test-web:
	rm -rf export
	make web
	(cd $(dir $(EXPORT_WEB_TARGET)) && python3 -m http.server)

clean:
	scons -c
	rm -rf build
	rm -rf bin

build:
	scons platform=linux
	scons platform=web target=template_release dlink_enabled=yes threads=no
