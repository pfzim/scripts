"""
Script to create a VM
"""
import re
from dcim.models import DeviceRole, Platform
from django.core.exceptions import ObjectDoesNotExist
from utilities.exceptions import AbortScript
from extras.models import Tag
from ipam.choices import IPAddressStatusChoices
from ipam.models import IPAddress, VRF, Prefix
from tenancy.choices import ContactPriorityChoices
from tenancy.models import Tenant, Contact, ContactAssignment, ContactRole
from virtualization.choices import VirtualMachineStatusChoices
from virtualization.models import Cluster, VirtualMachine, VMInterface, VirtualDisk
from extras.scripts import Script, StringVar, IPAddressWithMaskVar, ObjectVar, MultiObjectVar, ChoiceVar, IntegerVar, TextVar

class NewVM(Script):
    class Meta:
        name = "New VM"
        description = "Create a new VM"
        scheduling_enabled = False
        commit_default = False

    vm_name = StringVar(label="VM names (comma separated)", required=True)
    #vm_tags = MultiObjectVar(model=Tag, label="VM tags", required=False)
    role = ObjectVar(model=DeviceRole, query_params=dict(vm_role=True), required=True)
    #status = ChoiceVar(VirtualMachineStatusChoices, default=VirtualMachineStatusChoices.STATUS_ACTIVE)
    is_name = StringVar(label="IS Name", required=True)
    #interface_name = StringVar(default="eth0")
    net_prefix = ObjectVar(model=Prefix, query_params=dict(role='servers')) 
    cluster = ObjectVar(model=Cluster)
    contact_group = ObjectVar(model=Contact, query_params=dict(tag='mailing-list'), required=True)
    contact_owner = ObjectVar(model=Contact, query_params=dict(tag__n='mailing-list'), required=False)
    #tenant = ObjectVar(model=Tenant, required=False)
    platform = ObjectVar(model=Platform, required=True)
    #mac_address = StringVar(label="MAC address", required=False)
    vcpus = IntegerVar(label="VCPUs", required=True)
    memory = IntegerVar(label="Memory (GB)", required=True)
    # disk = IntegerVar(label="Disk (GB)", required=True)
    disks = StringVar(label="Disks comma separated (GB)", required=True)

    def run(self, data, commit):
        def create_vm(self, data, commit, vm_name):
            dns_name = str(vm_name) + ".example.org"
            disks = [int(j) for j in (x.strip() for x in re.split(r"\s*[,;]+\s*", data["disks"])) if j]

            ip_address = data['net_prefix'].get_first_available_ip()

            if not ip_address:
                raise AbortScript("No available IP in selected range")

            vm = VirtualMachine(
                name = vm_name,
                role=data["role"],
                status = VirtualMachineStatusChoices.STATUS_PLANNED,
                cluster = data['cluster'],
                platform = data['platform'],
                vcpus = data['vcpus'],
                memory = data['memory'] * 1024,
                disk = sum(disks),
                custom_field_data = dict(
                    cmdb_is = data['is_name'],
                    monitoring_default = True,
                    vm_cpu_compat = False,
                    vm_have_fc = False,
                    vm_nested = False,
                    vm_root_access = 'true'
                )
                #comments=data["comments"],
                #tenant=data.get("tenant"),
            )

            vm.full_clean()
            vm.save()

            vminterface = VMInterface(
                name = 'Ethernet' if 'win' in data['platform'].name.lower() else 'eth0',
                #mac_address=data["mac_address"],
                virtual_machine=vm,
                custom_field_data = dict(
                    vm_mac_spoof = False
                )
            )
            vminterface.full_clean()
            vminterface.save()

            addr = IPAddress(
                address=ip_address,
                status = IPAddressStatusChoices.STATUS_ACTIVE,
                dns_name = dns_name,
                vrf = data['net_prefix'].vrf,
                assigned_object = vminterface
            )

            addr.full_clean()
            addr.save()

            for i, disk_size in enumerate(disks):
                vdisk = VirtualDisk(
                    name = "disk" + str(i + 1),
                    size = disk_size,
                    virtual_machine = vm,
                    custom_field_data = dict(
                        vm_disk_boot = (i == 0),
                        vm_disk_mountpoint = None if (i != 0) else 'C:' if 'win' in data['platform'].name.lower() else '/'
                    )
                )

                vdisk.full_clean()
                vdisk.save()
            
            ca = ContactAssignment(object=vm, contact=data['contact_group'], role=role, priority=ContactPriorityChoices.PRIORITY_PRIMARY)
            ca.full_clean()
            ca.save()

            if data['contact_owner']:
                ContactAssignment(object=vm, contact=data['contact_owner'], role=role, priority=ContactPriorityChoices.PRIORITY_PRIMARY)
                ca.full_clean()
                ca.save()

            self.log_info(f"Created VM {vm_name}, {data['cluster'].name}, {ip_address}")

        vms = [j for j in (x.strip() for x in re.split(r"\s*[,;]+\s*", data["vm_name"])) if j]

        for vm_name in vms:
            if not re.match("^((srv|rc\\d+)-\\w+-\\d+)$|^(\\d{4}-[nNwWvV]\\d+)$|^(\\d{2}-\\d{4}-[vVmM]{0,1}\\d+)$|^(\\d{2}-[Ww][Hh]\\d{2}-\\d+)$|^(\\d{4}-[Ww]\\d{2}BK)$", vm_name):
                raise AbortScript(f"Invalid VM name: {vm_name}")

        if not 1 <= data['vcpus'] <= 12:
            raise AbortScript("vCPU out of range [1..12]")

        if not 1 <= data['memory'] <= 24:
            raise AbortScript("Memory out of range [1..24]")

        role = ContactRole.objects.get(slug = 'owner')
        if not role:
            raise AbortScript("Contact role not found")

        for vm_name in vms:
            create_vm(self, data, commit, vm_name)
