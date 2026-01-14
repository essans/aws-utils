# AWS-Utils Architecture

## Project Overview (created with claude-code)

**aws-utils** is a personal automation utility for streamlining the complete lifecycle of AWS EC2 instance management, from launch to fully-configured development environment in under 5 minutes.

## High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        CLI[ZSH Functions<br/>Quick CLI Commands]
        YAML[YAML Configs<br/>Declarative Specs]
    end

    subgraph "Application Layer"
        LAUNCH[ec2_launch_bootstrap.py<br/>Master Orchestrator]
        EC2PY[ec2_launch_from_yaml.py<br/>EC2 Launcher]
        PRICE[ec2_specs_price.py<br/>Price Query]
    end

    subgraph "Core Libraries"
        GETPRICE[get_prices.py<br/>AWS Pricing API]
        LOGGER[aws_logger.py<br/>Logging]
        UTILS[utils.py<br/>Helpers]
        CONFIG[user_configs.py<br/>Config Loader]
    end

    subgraph "Infrastructure Layer"
        TEMPLATES[Launch Templates<br/>16 YAML Files]
        BOOTSTRAP[Bootstrap System<br/>10 Modular Steps]
        AWS[AWS Resources<br/>EC2, VPC, Security Groups]
    end

    CLI --> PRICE
    CLI --> AWS
    YAML --> LAUNCH
    YAML --> BOOTSTRAP

    LAUNCH --> EC2PY
    LAUNCH --> GETPRICE
    LAUNCH --> BOOTSTRAP

    EC2PY --> TEMPLATES
    EC2PY --> AWS
    PRICE --> GETPRICE

    GETPRICE --> AWS
    LAUNCH --> LOGGER
    LAUNCH --> UTILS
    LAUNCH --> CONFIG
```

## Detailed Component Architecture

```mermaid
graph LR
    subgraph "Entry Points"
        USER[User]
        ZSH[ZSH Scripts]
        PYTHON[Python Scripts]
    end

    subgraph "Configuration"
        CT[config_template.yaml<br/>Bootstrap Config]
        LT[Launch Templates<br/>instance_specs.yaml]
        UC[user_configs.py<br/>Paths & Defaults]
    end

    subgraph "Core Python Modules"
        LB[ec2_launch_bootstrap.py<br/>Main Orchestrator]
        LF[ec2_launch_from_yaml.py<br/>EC2 Launcher]
        SP[ec2_specs_price.py<br/>Price Query]
        GP[get_prices.py<br/>Pricing API]
        LOG[aws_logger.py<br/>Logging]
        UT[utils.py<br/>Utilities]
    end

    subgraph "Bootstrap System"
        RUN[run.sh<br/>Bootstrap Runner]
        S00[00_preflight.sh<br/>Validation]
        S01[01_os_updates.sh<br/>System Setup]
        S02[02_git_etc.sh<br/>Git Config]
        S03[03_python_tooling.sh<br/>Python Env]
        S04[04_aws.sh<br/>AWS CLI]
        S05[05_other_setups.sh<br/>Misc]
        S06[06_torch_setup.sh<br/>PyTorch]
        S07[07_dlami_torch_verify.sh<br/>DLAMI Check]
        S08[08_claude_code.sh<br/>Claude Code]
        S09[09_ide_setup.sh<br/>IDE Setup]
    end

    subgraph "AWS Services"
        EC2[EC2 Instances]
        PRICING[Pricing API]
        VPC[VPC/Security Groups]
    end

    USER --> ZSH
    USER --> PYTHON

    ZSH --> SP
    ZSH --> EC2

    PYTHON --> LB
    PYTHON --> SP

    LB --> CT
    LB --> LT
    LB --> UC
    LB --> LF
    LB --> GP
    LB --> LOG
    LB --> UT

    LF --> EC2
    GP --> PRICING

    LB --> RUN
    RUN --> S00
    RUN --> S01
    RUN --> S02
    RUN --> S03
    RUN --> S04
    RUN --> S05
    RUN --> S06
    RUN --> S07
    RUN --> S08
    RUN --> S09
```

## Launch + Bootstrap Workflow

```mermaid
sequenceDiagram
    participant User
    participant ec2_launch_bootstrap.py
    participant config_template.yaml
    participant Launch Template
    participant AWS Pricing API
    participant ec2_launch_from_yaml.py
    participant AWS EC2
    participant Bootstrap (run.sh)
    participant Step Scripts

    User->>ec2_launch_bootstrap.py: Execute with config
    ec2_launch_bootstrap.py->>config_template.yaml: Load configuration
    ec2_launch_bootstrap.py->>Launch Template: Find matching template
    ec2_launch_bootstrap.py->>AWS Pricing API: Check current price

    alt Price acceptable
        ec2_launch_bootstrap.py->>ec2_launch_from_yaml.py: Launch instance
        ec2_launch_from_yaml.py->>AWS EC2: run_instances()
        AWS EC2-->>ec2_launch_from_yaml.py: Instance details + IP
        ec2_launch_bootstrap.py->>AWS EC2: Poll SSH (22) until ready

        ec2_launch_bootstrap.py->>AWS EC2: SCP bootstrap files
        ec2_launch_bootstrap.py->>Bootstrap (run.sh): SSH + execute

        Bootstrap (run.sh)->>Step Scripts: Execute 00_preflight.sh
        Bootstrap (run.sh)->>Step Scripts: Execute 01_os_updates.sh
        Bootstrap (run.sh)->>Step Scripts: Execute 02_git_etc.sh
        Bootstrap (run.sh)->>Step Scripts: Execute 03_python_tooling.sh
        Bootstrap (run.sh)->>Step Scripts: Execute 04_aws.sh
        Bootstrap (run.sh)->>Step Scripts: Execute 05-09 steps...

        Bootstrap (run.sh)-->>User: Fully configured instance
    else Price too high
        ec2_launch_bootstrap.py-->>User: Abort (price threshold exceeded)
    end
```

## Data Flow Architecture

```mermaid
flowchart TD
    A[User Config YAML] --> B[Launch Template YAML]
    B --> C[Parameter Validation]
    C --> D[Price Check]

    D -->|Price OK| E[boto3.ec2.run_instances]
    D -->|Too Expensive| F[Abort]

    E --> G[EC2 Instance Running]
    G --> H[Wait for SSH Port 22]
    H --> I[SCP Bootstrap Files]
    I --> J[SSH Execute run.sh]

    J --> K[Sequential Step Execution]
    K --> L[00: Preflight Checks]
    L --> M[01: OS Updates]
    M --> N[02: Git Config]
    N --> O[03: Python Env]
    O --> P[04: AWS CLI]
    P --> Q[05-09: Additional Steps]

    Q --> R[Configured Instance Ready]

    K --> S[State Tracking<br/>~/.bootstrap_state/]
    K --> T[Logging<br/>~/logs/aws/]
```

## Three-Layer Architecture

```mermaid
graph TB
    subgraph "Layer 1: CLI Interface"
        direction LR
        Z1[ec2_price.zsh<br/>Pricing Lookup]
        Z2[ec2_my_instances.zsh<br/>List Instances]
        Z3[ec2_specs.zsh<br/>Query Specs]
        Z4[ec2_images.zsh<br/>AMI Search]
    end

    subgraph "Layer 2: Application Logic"
        direction LR
        P1[ec2_launch_bootstrap.py<br/>Orchestration]
        P2[ec2_launch_from_yaml.py<br/>Launch Logic]
        P3[ec2_specs_price.py<br/>Price Queries]
        P4[get_prices.py<br/>API Wrapper]
    end

    subgraph "Layer 3: Infrastructure"
        direction LR
        I1[YAML Templates<br/>Declarative Specs]
        I2[Bootstrap Steps<br/>Shell Scripts]
        I3[AWS Resources<br/>EC2, VPC, etc]
    end

    Z1 --> P3
    Z2 --> I3
    Z3 --> P3
    Z4 --> I3

    P1 --> P2
    P1 --> P4
    P2 --> I1
    P2 --> I3
    P3 --> P4
    P4 --> I3

    P1 --> I2
    I2 --> I3
```

## Bootstrap System Architecture

```mermaid
graph TD
    START[run.sh Entry Point]
    START --> PARSE[Parse Config YAML]
    PARSE --> FILTER[Apply Filters<br/>--skip, --only]

    FILTER --> CHECK1{Step Done?}
    CHECK1 -->|Yes & No Force| SKIP1[Skip Step]
    CHECK1 -->|No or Force| EXEC1[Execute 00_preflight.sh]

    EXEC1 --> SOURCE1[Source ~/.bashrc]
    SOURCE1 --> MARK1[Mark Done]
    MARK1 --> CHECK2{Step Done?}

    CHECK2 -->|Yes & No Force| SKIP2[Skip Step]
    CHECK2 -->|No or Force| EXEC2[Execute 01_os_updates.sh]

    EXEC2 --> SOURCE2[Source ~/.bashrc]
    SOURCE2 --> MARK2[Mark Done]
    MARK2 --> MORE[... Continue for 02-09]

    MORE --> END[Bootstrap Complete]

    EXEC1 -.-> LOG[bootstrap.log]
    EXEC2 -.-> LOG
    MORE -.-> LOG

    MARK1 -.-> STATE[~/.bootstrap_state/]
    MARK2 -.-> STATE
```

## Key Architectural Patterns

### 1. Declarative Configuration
- All instance specifications in YAML (not hardcoded)
- Bootstrap steps and requirements in config_template.yaml
- Enables templating, versioning, and reusability

### 2. Modular Bootstrap Design
- Independent shell scripts with numeric prefixes (00-09)
- Each step can be executed, skipped, or forced independently
- Dry-run mode for safety
- State files prevent accidental re-execution

### 3. Separation of Concerns
- **aws_logger.py**: Centralized logging
- **get_prices.py**: Dedicated pricing API wrapper
- **utils.py**: Reusable utilities
- **user_configs.py**: Single source of truth for paths

### 4. Defensive Programming
- Duplicate instance detection before launch
- Price validation before instance creation
- SSH readiness polling with timeout
- Comprehensive pre-flight checks
- Fallback values in pricing lookups

### 5. Type Safety
- Python 3.12+ with strict mypy configuration
- Ruff linting with modern Python rules
- Proper type hints in core functions

## Directory Structure

```
aws-utils/
├── bootstrap/              # Bootstrap system
│   ├── run.sh             # Master orchestrator
│   ├── steps/             # 10 modular setup scripts (00-09)
│   └── config_template.yaml
├── configs/               # Configuration
│   ├── user_configs.py    # Central config loader
│   └── regions.yaml       # AWS region mappings
├── docs/                  # Documentation
│   ├── step_0_overview_setup.md
│   ├── step_1_launch_manage_ec2.md
│   ├── step_2_instance_setup.md
│   └── step_3_one_shot_launch_bootstrap.md
├── launch/                # 16 YAML launch templates
│   ├── t/                 # t-family instances
│   ├── c/                 # c-family instances
│   ├── g/                 # g-family instances
│   └── ...
├── scripts/               # Core Python scripts
│   ├── ec2_launch_bootstrap.py
│   ├── ec2_launch_from_yaml.py
│   └── ec2_specs_price.py
├── src/                   # Source libraries
│   ├── get_prices.py
│   ├── aws_logger.py
│   └── utils.py
├── zsh_general_info/      # General info queries
│   ├── ec2_price.zsh
│   ├── ec2_specs.zsh
│   └── ...
└── zsh_my_instances/      # Instance management
    ├── ec2_my_instances.zsh
    └── ...
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **ec2_launch_bootstrap.py** | Orchestrates full launch + bootstrap workflow |
| **ec2_launch_from_yaml.py** | Parses YAML and launches EC2 via boto3 |
| **ec2_specs_price.py** | CLI tool for querying instance pricing |
| **get_prices.py** | Wraps AWS Pricing API with error handling |
| **aws_logger.py** | Tracks AWS operations with timestamps and metadata |
| **run.sh** | Sequences bootstrap steps with state tracking |
| **00_preflight.sh** | Validates OS, architecture, disk, network |
| **01-09 steps** | Modular system configuration tasks |
| **config_template.yaml** | Defines bootstrap inputs and requirements |
| **Launch templates** | Pre-configured instance specifications |
| **ZSH functions** | Quick CLI access to AWS operations |

## Design Philosophy

1. **Minimize Friction**: Complete setup from bare instance to dev-ready in <5 minutes
2. **Treat as Ephemeral**: Launch/teardown on-demand to minimize idle costs
3. **Declarative Over Imperative**: YAML configs over hardcoded parameters
4. **Modular & Extensible**: Easy to add new bootstrap steps or templates
5. **Defensive & Safe**: Validation, dry-runs, state tracking, error handling
6. **Type-Safe & Modern**: Python 3.12+, mypy, ruff, proper error handling
