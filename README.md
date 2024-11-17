# Packer Tutorial

Este repositorio contiene ejemplos y guías para aprender a utilizar **Packer** para crear imágenes de infraestructura como código (IaC) de manera automatizada y consistente. Packer es una herramienta de HashiCorp que te permite crear imágenes de máquina para múltiples plataformas de manera repetible.

## Requisitos Previos

Antes de comenzar, asegúrate de tener las siguientes herramientas instaladas:

- **Packer**: Puedes descargarlo desde [la página oficial de Packer](https://www.packer.io/downloads).
- **Docker** (si estás trabajando con Docker).
- **AWS CLI** (si estás trabajando con AWS).

## Comandos Básicos de Packer

Packer ofrece varios comandos que te permiten gestionar las plantillas, inicializar la configuración, formatear y validar archivos, y construir imágenes. Aquí te explicamos algunos de los más importantes:

### 1. Inicializar la Configuración de Packer

El primer paso al trabajar con Packer es inicializar la configuración. Este comando descarga los plugins necesarios según lo definido en tu plantilla.

```bash
packer init .
```

**¿Qué hace este comando?**

- Descarga e instala los plugins definidos en tu plantilla. Por ejemplo, si estás trabajando con Docker, descargará el plugin de Docker.
- Si los plugins ya están instalados, Packer no hará nada.

### 2. Formatear la Plantilla de Packer

El comando `packer fmt` ajusta el formato de las plantillas para mejorar su legibilidad y consistencia.

```bash
packer fmt .
```

**¿Qué hace este comando?**

- Este comando organiza y da formato a tus archivos `.pkr.hcl` para asegurarse de que sean más legibles y consistentes. Si el archivo ya está bien formateado, no hará cambios.

### 3. Validar la Plantilla de Packer

Es importante asegurarse de que la plantilla de Packer esté libre de errores sintácticos y sea válida antes de usarla. El comando `packer validate` realiza esta validación.

```bash
packer validate .
```

**¿Qué hace este comando?**

- Este comando verifica que la plantilla no tenga errores en su sintaxis y que todos los valores y parámetros estén correctamente configurados.
- Si la plantilla es válida, no se mostrará ningún mensaje; si hay errores, Packer te indicará qué líneas y qué tipo de error existe.

### 4. Construir la Imagen

Una vez que tu plantilla esté lista, el comando `packer build` es el que crea la imagen según la configuración especificada.

```bash
packer build <archivo>.pkr.hcl
```

**¿Qué hace este comando?**

- Packer comienza a construir la imagen, utilizando la plantilla que has definido. Dependiendo de los _builders_ y _provisioners_ que hayas especificado, Packer descargará imágenes base, configurará máquinas virtuales o contenedores, y aplicará los cambios definidos.
- El archivo resultante es una imagen de máquina que se puede usar en entornos de producción.

## Explicación de la Plantilla Packer (Ejemplo General)

Aquí te presentamos un ejemplo general de cómo se estructura una plantilla de **Packer** en HCL (HashiCorp Configuration Language).

### Ejemplo de Plantilla Packer en HCL

```hcl
packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "ubuntu" {
  image  = "ubuntu:jammy"
  commit = true
}

build {
  name = "learn-packer"
  sources = [
    "source.docker.ubuntu"
  ]
}
```

### Descripción de las Secciones de una Plantilla Packer

1. **`packer { required_plugins { ... } }`**:
   - Esta sección es utilizada para definir los plugins que Packer necesita para trabajar. En este caso, se está solicitando el plugin de Docker (aunque si trabajas con AWS, usarías el plugin `amazon`).
   - Especificas la versión mínima del plugin que necesitas y la fuente del plugin (en este caso, desde el repositorio de HashiCorp en GitHub).
2. **`source "docker" "ubuntu" { ... }`**:

   - En esta sección se define un _builder_ (constructor) que indica el tipo de recurso que deseas crear. En este caso, estamos utilizando el _builder_ de Docker para crear una imagen basada en Ubuntu.
   - **`image`**: Especifica la imagen base que se utilizará (en este caso, `ubuntu:jammy`).
   - **`commit`**: Este parámetro indica que una vez que se hayan realizado los cambios en el contenedor, Packer debe hacer un `commit` para guardar el estado final de la imagen.

3. **`build { ... }`**:
   - El bloque `build` es donde se configuran los pasos de construcción de la imagen. En este caso, estamos construyendo una imagen Docker basada en la fuente de Docker que definimos antes (`source.docker.ubuntu`).
   - **`name`**: Define un nombre para el proceso de construcción. No es obligatorio, pero es útil para identificar el proceso en los registros.
   - **`sources`**: Aquí defines las fuentes de los _builders_ que utilizarás. En este caso, estamos usando `source.docker.ubuntu`, que corresponde al _builder_ que definimos previamente.

## Conclusión

Packer es una herramienta poderosa y flexible para automatizar la creación de imágenes de infraestructura para múltiples plataformas. Ya sea que estés trabajando con Docker, AWS o cualquier otra plataforma, Packer te permite definir tu infraestructura como código y crear imágenes de manera repetible y consistente.

Este repositorio contiene ejemplos tanto para Docker como para AWS, y puedes extenderlo para experimentar con otras plataformas soportadas por Packer.
