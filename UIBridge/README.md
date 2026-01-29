# UIBridge

UIBridge is a runtime control plane for GNUstep applications, enabling developers and autonomous systems to inspect, manipulate, and automate GUI applications. By leveraging the built-in introspection of the **Eau theme**, UIBridge exposes the live Objective-C object graph through a Model Context Protocol (MCP) interface.

## Key Features

- **Native Theme Integration**: Works automatically with applications using the Eau theme, leveraging native GNUstep Distributed Objects for introspection.
- **Dynamic Object Access**: Provides direct access to live AppKit objects, including windows, views, and menus, using a stable pointer-based identity system.
- **Remote Execution**: Supports invoking arbitrary selectors on remote objects, enabling sophisticated automation and state manipulation.
- **System Integration**: Combines high-level AppKit introspection with low-level X11 window management and LLDB-based process debugging.
- **Gershwin Ready**: Designed specifically for AI-driven workflows, providing a deterministic and semantic interface for LLMs.

## Components

The UIBridge architecture consists of:

- **Eau Theme UIBridge Service**: A component within the Eau theme that runs inside the target application's memory space, providing access to the Objective-C runtime via Distributed Objects.
- **UIBridge Server**: An MCP-compliant coordinator that manages the lifecycle of target applications and proxies requests between clients and applications.
- **Common Interface**: A shared protocol definition that ensures type-safe communication and consistent serialization of Objective-C objects.

## Documentation

For detailed information on how UIBridge works and how to use it, see:

- [Architecture Guide](ARCHITECTURE.md): Deep dive into the theme integration, object registry, and communication protocols.
- [Usage Guide](USAGE.md): Instructions for installation, building, and interacting with the system using MCP tools.
