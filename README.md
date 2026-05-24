<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase">
  <img src="https://img.shields.io/badge/Status-Active-success?style=for-the-badge" alt="Status">
</p>

<h1 align="center">Althea</h1>
<p align="center">Sistema de Gestión Hospitalaria moderno y eficiente</p>

<p align="center">
  Una aplicación Flutter multiplataforma diseñada para transformar la gestión hospitalaria, conectando pacientes, doctores, recepcionistas y administradores en un ecosistema integrado.
</p>

<details open="open">
  <summary><h2 style="display: inline-block">📋 Table of Contents</h2></summary>
  <ol>
    <li>
      <a href="#about">Sobre Althea</a>
      <ul>
        <li><a href="#features">Características</a></li>
        <li><a href="#user-roles">Roles de Usuario</a></li>
      </ul>
    </li>
    <li><a href="#getting-started">Comenzando</a></li>
    <li><a href="#project-structure">Estructura del Proyecto</a></li>
    <li><a href="#tech-stack">Stack Tecnológico</a></li>
    <li><a href="#contributing">Contribuir</a></li>
    <li><a href="#license">Licencia</a></li>
  </ol>
</details>

---

## Sobre Althea

Althea nace con la misión de simplificar la gestión hospitalaria a través de tecnología moderna. Nuestra plataforma permite una gestión fluida de citas, historias clínicas, horarios médicos y sedes, todo en una interfaz intuitiva y accesible.

### Características

- 🏥 **Gestión Integral**: Control completo de citas, historias clínicas y horarios
- 👥 **Múltiples Roles**: Pacientes, doctores, recepcionistas y administradores
- 📅 **Agenda Inteligente**: Sistema de agendamiento con bloqueos de fechas y horarios
- 🏢 **Múltiples Sedes**: Gestión de diferentes ubicaciones hospitalarias
- 💳 **Pagos Integrados**: Sistema de pagos para citas médicas
- 🎨 **UI/UX Moderna**: Diseño elegante y experiencia de usuario fluida
- 🌐 **Multiplataforma**: Funciona en web, iOS y Android

### Roles de Usuario

#### 👤 Paciente
- Explorar médicos disponibles y sus especialidades
- Agendar citas de manera sencilla
- Ver historial de citas y próximas citas
- Gestionar perfil personal

#### 👨‍⚕️ Doctor
- Visualizar agenda y horarios configurables
- Gestionar pacientes asignados
- Acceder a historias clínicas
- Bloquear fechas y horarios específicos
- Configurar horarios por sucursal y día de la semana

#### 📋 Recepcionista
- Buscar y gestionar pacientes
- Agendar citas en nombre de pacientes
- Coordinar con doctores y sedes

#### 👔 Administrador
- Gestionar sedes hospitalarias
- Administrar médicos (crear, editar, eliminar)
- Supervisión general del sistema

---

## Comenzando

### Requisitos Previos

- Flutter SDK (3.0 o superior)
- Dart SDK
- Android Studio / VS Code / Xcode
- Cuenta en Supabase (para backend)

### Instalación

1. **Clona el repositorio**
   ```bash
   git clone https://github.com/tu-usuario/althea.git
   cd althea
   ```

2. **Instala las dependencias**
   ```bash
   flutter pub get
   ```

3. **Configura el entorno**
   
   Crea un archivo `.env` en la raíz del proyecto con tus credenciales de Supabase:
   ```env
   SUPABASE_URL=tu_supabase_url
   SUPABASE_ANON_KEY=tu_supabase_anon_key
   ```

4. **Ejecuta la aplicación**
   ```bash
   flutter run
   ```

### Configuración de Base de Datos

Althea utiliza Supabase como backend. Asegúrate de configurar las siguientes tablas en tu proyecto de Supabase:

- `usuarios` - Información de usuarios
- `doctores` - Perfiles de doctores
- `pacientes` - Perfiles de pacientes
- `sucursales` - Sedes hospitalarias
- `citas` - Citas médicas
- `horarios_doctor` - Horarios de atención por día
- `bloqueos_doctor` - Bloqueos de fechas y horarios

---

## Estructura del Proyecto

```
lib/
├── core/
│   ├── config/          # Configuración de la app
│   ├── models/          # Modelos de datos
│   ├── providers/       # State management
│   ├── theme/           # Tema y estilos
│   └── utils/           # Utilidades
├── features/
│   ├── auth/            # Autenticación
│   ├── patient/         # Módulo de paciente
│   ├── doctor/          # Módulo de doctor
│   ├── receptionist/    # Módulo de recepcionista
│   └── admin/           # Módulo de administrador
└── shared/
    ├── widgets/         # Widgets reutilizables
    └── services/        # Servicios compartidos
```

---

## Stack Tecnológico

- **Frontend**: Flutter
- **Lenguaje**: Dart
- **Backend**: Supabase
- **State Management**: Provider
- **Routing**: go_router
- **Base de Datos**: PostgreSQL (vía Supabase)
- **Autenticación**: Supabase Auth

---

## Contribuir

¡Las contribuciones son bienvenidas! Si deseas mejorar Althea:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

Por favor, sigue las mejores prácticas de desarrollo y mantén el código limpio y bien documentado.

---

## Licencia

Este proyecto es propiedad de sus desarrolladores. Todos los derechos reservados.

---

<p align="center">
  <sub>Hecho con amors por el equipo de Althea</sub>
</p>
