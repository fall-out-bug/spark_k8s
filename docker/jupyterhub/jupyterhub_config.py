"""
JupyterHub Configuration with KubeSpawner
"""
import os

# --- JupyterHub Settings ---
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.port = 8000
c.JupyterHub.hub_ip = '0.0.0.0'

# Allow named servers (multiple notebooks per user)
c.JupyterHub.allow_named_servers = True
c.JupyterHub.named_server_limit_per_user = 3

# --- Authentication ---
# Native Authenticator (simple username/password)
c.JupyterHub.authenticator_class = 'nativeauthenticator.NativeAuthenticator'
c.NativeAuthenticator.open_signup = True  # Allow self-registration
c.NativeAuthenticator.minimum_password_length = 6
c.NativeAuthenticator.check_common_password = False
c.NativeAuthenticator.allowed_failed_logins = 5

# Admin users (can manage other users)
c.Authenticator.admin_users = {'admin'}

# Create default admin user
c.NativeAuthenticator.create_admin_user_at_startup = True
c.NativeAuthenticator.admin_user_data = {
    'username': 'admin',
    'password': os.environ.get('JUPYTERHUB_ADMIN_PASSWORD', 'admin123')
}

# --- KubeSpawner ---
c.JupyterHub.spawner_class = 'kubespawner.KubeSpawner'

# Kubernetes namespace
c.KubeSpawner.namespace = os.environ.get('NAMESPACE', 'spark')

# Single-user server image
c.KubeSpawner.image = os.environ.get('SINGLEUSER_IMAGE', 'jupyter-spark:latest')
c.KubeSpawner.image_pull_policy = 'IfNotPresent'

# Service account for user pods
c.KubeSpawner.service_account = os.environ.get('SERVICE_ACCOUNT', 'spark')

# Resources for user pods
c.KubeSpawner.cpu_limit = float(os.environ.get('SINGLEUSER_CPU_LIMIT', '2'))
c.KubeSpawner.cpu_guarantee = float(os.environ.get('SINGLEUSER_CPU_GUARANTEE', '0.5'))
c.KubeSpawner.mem_limit = os.environ.get('SINGLEUSER_MEM_LIMIT', '4G')
c.KubeSpawner.mem_guarantee = os.environ.get('SINGLEUSER_MEM_GUARANTEE', '1G')

# Pod naming
c.KubeSpawner.pod_name_template = 'jupyter-{username}--{servername}'

# Environment variables for user pods
c.KubeSpawner.environment = {
    'SPARK_REMOTE': os.environ.get('SPARK_REMOTE', 'sc://spark-connect:15002'),
    'S3_ENDPOINT': os.environ.get('S3_ENDPOINT', 'http://minio:9000'),
    'PYARROW_IGNORE_TIMEZONE': '1',
}

# Inject S3 credentials from secret into user pods
c.KubeSpawner.extra_container_config = {
    'env': [
        {
            'name': 'AWS_ACCESS_KEY_ID',
            'valueFrom': {
                'secretKeyRef': {
                    'name': 's3-credentials',
                    'key': 'access-key'
                }
            }
        },
        {
            'name': 'AWS_SECRET_ACCESS_KEY',
            'valueFrom': {
                'secretKeyRef': {
                    'name': 's3-credentials',
                    'key': 'secret-key'
                }
            }
        }
    ]
}

# Storage - persistent home directories (optional)
# Uncomment to enable persistent storage for each user
# c.KubeSpawner.storage_pvc_ensure = True
# c.KubeSpawner.storage_class = ''
# c.KubeSpawner.storage_access_modes = ['ReadWriteOnce']
# c.KubeSpawner.storage_capacity = '5Gi'
# c.KubeSpawner.pvc_name_template = 'jupyter-{username}'
# c.KubeSpawner.volume_mounts = [
#     {'name': 'volume-{username}', 'mountPath': '/home/jupyter'}
# ]
# c.KubeSpawner.volumes = [
#     {'name': 'volume-{username}', 'persistentVolumeClaim': {'claimName': 'jupyter-{username}'}}
# ]

# Shared notebooks volume (read-only examples)
c.KubeSpawner.volumes = [
    {
        'name': 'shared-notebooks',
        'configMap': {
            'name': 'jupyter-notebooks'
        }
    }
]
c.KubeSpawner.volume_mounts = [
    {
        'name': 'shared-notebooks',
        'mountPath': '/home/jupyter/examples',
        'readOnly': True
    }
]

# Timeouts
c.KubeSpawner.start_timeout = 300  # 5 minutes
c.KubeSpawner.http_timeout = 60

# Culling idle servers
c.JupyterHub.services = [
    {
        'name': 'cull-idle',
        'admin': True,
        'command': [
            'python3', '-m', 'jupyterhub_idle_culler',
            '--timeout=3600',  # 1 hour idle timeout
            '--max-age=86400',  # 24 hour max age
            '--cull-every=300'  # Check every 5 minutes
        ],
    }
]

# Labels for user pods
c.KubeSpawner.common_labels = {
    'app': 'jupyterhub',
    'component': 'singleuser-server'
}

# Node selector (optional - uncomment to schedule on specific nodes)
# c.KubeSpawner.node_selector = {'node-type': 'jupyter'}

# Tolerations (optional)
# c.KubeSpawner.tolerations = [
#     {'key': 'jupyter', 'operator': 'Equal', 'value': 'true', 'effect': 'NoSchedule'}
# ]

# --- Profile Selection ---
# Allow users to choose between different resource profiles
c.KubeSpawner.profile_list = [
    {
        'display_name': 'Small (1 CPU, 2GB RAM)',
        'description': 'For light data exploration',
        'kubespawner_override': {
            'cpu_limit': 1,
            'cpu_guarantee': 0.25,
            'mem_limit': '2G',
            'mem_guarantee': '512M'
        }
    },
    {
        'display_name': 'Medium (2 CPU, 4GB RAM)',
        'description': 'For typical data analysis',
        'default': True,
        'kubespawner_override': {
            'cpu_limit': 2,
            'cpu_guarantee': 0.5,
            'mem_limit': '4G',
            'mem_guarantee': '1G'
        }
    },
    {
        'display_name': 'Large (4 CPU, 8GB RAM)',
        'description': 'For heavy data processing',
        'kubespawner_override': {
            'cpu_limit': 4,
            'cpu_guarantee': 1,
            'mem_limit': '8G',
            'mem_guarantee': '2G'
        }
    }
]
