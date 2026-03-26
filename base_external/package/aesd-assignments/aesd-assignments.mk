# Reemplaza 'master' por el hash de tu commit si quieres fijar una versión
AESD_ASSIGNMENTS_VERSION = 5da11191e69de2353e12e9e537074014d613670b
# Asegúrate de que esta URL sea la de tu repo de la TAREA 3 (donde está el código)
AESD_ASSIGNMENTS_SITE = git@github.com:jaRamirezAg/assignment-4-jaRamirezAg.git
AESD_ASSIGNMENTS_SITE_METHOD = git
AESD_ASSIGNMENTS_GIT_SUBMODULES = YES

define AESD_ASSIGNMENTS_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)/finder-app all
endef

define AESD_ASSIGNMENTS_INSTALL_TARGET_CMDS
	# 1. Crear directorios necesarios en el sistema de archivos destino (target)
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -d $(TARGET_DIR)/etc/finder-app/conf

	# 2. Instalar ejecutables y scripts en /usr/bin
	$(INSTALL) -m 0755 $(@D)/finder-app/writer $(TARGET_DIR)/usr/bin/
	$(INSTALL) -m 0755 $(@D)/finder-app/finder.sh $(TARGET_DIR)/usr/bin/
	$(INSTALL) -m 0755 $(@D)/finder-app/finder-test.sh $(TARGET_DIR)/usr/bin/

	# 3. Instalar archivos de configuración
	$(INSTALL) -m 0644 $(@D)/conf/assignment.txt $(TARGET_DIR)/etc/finder-app/conf/
	$(INSTALL) -m 0644 $(@D)/conf/username.txt $(TARGET_DIR)/etc/finder-app/conf/
endef

$(eval $(generic-package))