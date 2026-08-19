# AWS VPC Security — Break & Fix Lab

> **Senior DevOps / AWS Cloud Architect Interview Lab**

## 1. Lab Objective

Build a small AWS VPC, make the traffic flow work end-to-end, then intentionally break one security or networking layer at a time. For every failure, identify the layer responsible, observe the symptom, determine the root cause, and fix it.

---

## 2. Core Mental Model

Do not memorize a single linear packet-processing order. Instead, know where each control lives and what it controls.

```
Internet
   ↓
 Internet Gateway
   ↓
 Public Subnet
   ├── NACL (subnet-level network filter)
   └── ALB + ALB Security Group
         ↓
        WAF (HTTP/HTTPS / application layer)
         ↓
 Private Subnet
   ├── NACL (subnet-level network filter)
   └── EC2 ENI + EC2 Security Group
         ↓
      Application
```

---

## 3. What Each Layer Does

| Layer             | Control        | Scope            | Purpose                                        |
|-------------------|----------------|------------------|-------------------------------------------------|
| Application       | WAF            | HTTP/HTTPS       | Inspects and blocks web requests                |
| Load Balancer     | ALB            | Application      | Receives and distributes requests               |
| Network Interface | Security Group | ENI              | Allows traffic by protocol, port, and source    |
| Subnet            | NACL           | Entire subnet    | Allows/denies inbound and outbound traffic      |
| Subnet            | Route Table    | Subnet routing   | Determines where traffic should go              |
| VPC               | VPC            | Network boundary | Provides CIDR/address space and isolation       |

> **Key distinction:** Route tables decide **WHERE** traffic goes. NACLs and Security Groups control **WHETHER** traffic is allowed. WAF evaluates web/application requests.

---

## 4. Lab Architecture

```
VPC: 172.16.0.0/16
 │
 ├── Public Subnet 1: 172.16.0.0/24 (us-east-1a)
 │   └── ALB + NAT Gateway
 │
 ├── Public Subnet 2: 172.16.1.0/24 (us-east-1b)
 │   └── ALB (second AZ, required by AWS)
 │
 ├── Private Subnet 1: 172.16.2.0/24 (us-east-1a)
 │   └── EC2 running Python HTTP server on port 8080
 │
 └── Private Subnet 2: 172.16.3.0/24 (us-east-1b)
     └── (available for scaling)

 Public Route Table:
   0.0.0.0/0 → Internet Gateway

 Private Route Table:
   0.0.0.0/0 → NAT Gateway
```

### Traffic Flow

```
User (HTTP :80) → IGW → ALB (public subnets) → EC2 :8080 (private subnet)
```

---

## 5. Baseline Security Rules

### ALB Security Group (`alb_sg`)

| Direction | Protocol | Port | Source/Destination      |
|-----------|----------|------|-------------------------|
| Ingress   | TCP      | 80   | `0.0.0.0/0`            |
| Egress    | TCP      | 8080 | `ec2_sg` (SG-to-SG)    |

### EC2 Security Group (`ec2_sg`)

| Direction | Protocol | Port | Source/Destination      |
|-----------|----------|------|-------------------------|
| Ingress   | TCP      | 8080 | `alb_sg` (SG-to-SG)    |
| Ingress   | TCP      | 22   | `0.0.0.0/0`            |
| Egress    | All      | All  | `0.0.0.0/0`            |

> **Important:** EC2 does **NOT** allow TCP/8080 directly from `0.0.0.0/0`. Only the ALB security group is trusted.

### Private Subnet NACL (`custom_private_nacl`)

| Direction | Rule # | Protocol | Port Range  | Source/Destination   | Action |
|-----------|--------|----------|-------------|----------------------|--------|
| Ingress   | 100    | TCP      | 8080        | `172.16.0.0/16`      | ALLOW  |
| Egress    | 100    | TCP      | 1024–65535  | `172.16.0.0/16`      | ALLOW  |

This gives the desired trust relationship:

```
Internet → ALB → EC2 (only via ALB SG)
```

---

## 6. Baseline Test

The EC2 instance runs a Python HTTP server via `userdata.sh`:

```python
# Runs on port 8080, responds with hostname and request path
server = HTTPServer(("0.0.0.0", 8080), Handler)
```

Test the ALB:

```bash
curl http://<ALB-DNS-NAME>
```

**Baseline must work before starting any Break & Fix scenario.**

---

## 7. Break & Fix Scenarios

### Break #01 — ALB Security Group

| Item          | Detail |
|---------------|--------|
| **Break**     | Change ALB SG so TCP/80 is not allowed from the client |
| **Traffic**   | `Internet → IGW → subnet/NACL → ALB ENI → ALB SG → ❌ BLOCK` |
| **Observe**   | ALB cannot be reached; `curl` times out |
| **Fix**       | Restore TCP/80 access for the intended client source |
| **File**      | `securityGroup.tf` → `alb-public-ingress` |
| **Lesson**    | Security Group is attached to the ENI and controls allowed traffic |

---

### Break #02 — Private Subnet NACL Inbound

| Item          | Detail |
|---------------|--------|
| **Break**     | Add a DENY rule for TCP/8080 to the private subnet NACL |
| **Traffic**   | `ALB → private subnet → NACL → ❌ BLOCK → EC2` |
| **Observe**   | ALB target becomes unhealthy |
| **Fix**       | Remove the DENY or add the correct ALLOW rule |
| **File**      | `nacl.tf` → `private_nacl_ingress_rule` |
| **Lesson**    | NACL is a subnet-level traffic filter |

---

### Break #03 — NACL Stateless Return Traffic

| Item          | Detail |
|---------------|--------|
| **Break**     | Allow inbound traffic but make the outbound NACL too restrictive (e.g., remove ephemeral port range) |
| **Traffic**   | Request reaches EC2, but `return traffic → NACL egress → ❌ BLOCK` |
| **Observe**   | Connection times out despite correct inbound rule |
| **Fix**       | Allow return traffic on ephemeral ports (1024–65535) |
| **File**      | `nacl.tf` → `private_nacl_egress_rule` |
| **Lesson**    | NACLs are **stateless**; inbound and outbound traffic are evaluated independently |

---

### Break #04 — EC2 Security Group

| Item          | Detail |
|---------------|--------|
| **Break**     | Change EC2 SG so TCP/8080 is not allowed from the ALB SG |
| **Traffic**   | `ALB → EC2 ENI → Security Group → ❌ BLOCK` |
| **Observe**   | ALB target becomes unhealthy / application unreachable |
| **Fix**       | Allow TCP/8080 from the ALB Security Group |
| **File**      | `securityGroup.tf` → `alb-ec2-ingress` |
| **Lesson**    | Security Groups operate at the ENI level and are **stateful** |

---

### Break #05 — Route Table

| Item          | Detail |
|---------------|--------|
| **Break**     | Remove or misconfigure the route needed by the traffic path (e.g., delete `0.0.0.0/0 → IGW`) |
| **Traffic**   | Traffic has no valid route to its destination |
| **Observe**   | Connectivity fails even though SG and NACL rules look correct |
| **Fix**       | Restore the correct route |
| **File**      | `routeTables.tf` → `public_subnet_rt` or `private_subnet_rt` |
| **Lesson**    | Routing failure is different from a security-control failure |

---

### Break #06 — WAF

| Item          | Detail |
|---------------|--------|
| **Break**     | Associate a WAF WebACL with the ALB and block a specific URI such as `/blocked` |
| **Traffic**   | HTTP request reaches the application layer and WAF blocks it |
| **Observe**   | `curl /` works, but `curl /blocked` returns 403 Forbidden |
| **Fix**       | Remove or adjust the WAF rule |
| **File**      | Create a new `waf.tf` |
| **Lesson**    | WAF is an application-layer control; it evaluates HTTP/HTTPS requests |

---

### Break #07 — Public EC2 Exposure

| Item          | Detail |
|---------------|--------|
| **Break**     | Allow EC2 TCP/8080 from `0.0.0.0/0` instead of the ALB SG |
| **Traffic**   | Internet can potentially reach EC2 directly, bypassing the ALB |
| **Observe**   | Application is exposed outside the intended ALB path |
| **Fix**       | Restrict EC2 SG to the ALB Security Group only |
| **File**      | `securityGroup.tf` → `alb-ec2-ingress` |
| **Lesson**    | Use SG-to-SG trust instead of broad internet access |

---

### Break #08 — NACL Rule Ordering

| Item          | Detail |
|---------------|--------|
| **Break**     | Create conflicting NACL rules with different rule numbers (e.g., DENY at rule 50, ALLOW at rule 100) |
| **Traffic**   | The first matching rule (lowest number) determines the result |
| **Observe**   | Traffic is unexpectedly denied despite an ALLOW rule existing |
| **Fix**       | Fix rule numbering and remove unnecessary conflicts |
| **File**      | `nacl.tf` |
| **Lesson**    | NACL rules are evaluated in ascending rule-number order; first match wins |

---

## 8. Troubleshooting Decision Tree

```
curl http://<ALB-DNS>
   ↓
 Can the client reach the ALB?
   ├─ NO → Check: Route Table → ALB subnet NACL → ALB Security Group
   │
   └─ YES → Is ALB target healthy?
              ├─ NO → Check: Target subnet NACL → EC2 Security Group → port/app
              │
              └─ YES → Test application response
                         ↓
                 If only certain HTTP requests fail:
                   → Investigate WAF rules and application behavior
```

---

## 9. Repository Structure

```
aws-app-security-terraform/
├── README.md                 # This file
├── provider.tf               # AWS provider (us-east-1, v6.x)
├── backend.tf                # S3 remote state backend
├── vpc.tf                    # VPC: 172.16.0.0/16
├── subnet.tf                 # 2 public + 2 private subnets across 2 AZs
├── igw.tf                    # Internet Gateway
├── ngw.tf                    # NAT Gateway (in public subnet 1)
├── eip.tf                    # Elastic IP for NAT Gateway
├── routeTables.tf            # Public (→ IGW) and Private (→ NAT GW) route tables
├── securityGroup.tf          # ALB SG and EC2 SG with ingress/egress rules
├── nacl.tf                   # Custom NACL for private subnet
├── alb.tf                    # ALB, target group, listener, target group attachment
├── ec2.tf                    # EC2 instance in private subnet
└── userdata.sh               # Python HTTP server on port 8080
```

---

## 10. Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform ≥ 1.x with AWS provider `~> 6.0`
- S3 bucket `roboshop-aws-terraform` for remote state

### Deploy

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### Test Baseline

```bash
# Get ALB DNS name from AWS Console or:
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names app-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl http://$ALB_DNS
```

### Destroy

```bash
terraform destroy -auto-approve
```

---

## 11. Break → Observe → Root Cause → Fix

Use this exact format for every scenario:

| Step          | Action |
|---------------|--------|
| **1. Break**   | Intentionally introduce one failure |
| **2. Observe** | Record `curl` output, ALB target health, and relevant AWS state |
| **3. Root Cause** | Identify the exact layer: routing, NACL, Security Group, WAF, or application |
| **4. Fix**     | Change only what is necessary |
| **5. Lesson**  | Write the one interview-level concept learned |

> The objective is not merely to make Terraform apply successfully; it is to develop the ability to identify **which layer** caused a connectivity failure.

---

## 12. Interview-Level Questions

After completing the lab, you should be able to answer:

1. What is the difference between a Security Group and a NACL?
2. Why is a Security Group **stateful**?
3. Why is a NACL **stateless**?
4. Where is a Security Group attached?
5. Where is a NACL associated?
6. Can a route table block traffic?
7. What does the VPC itself provide?
8. Why should EC2 accept traffic from the ALB Security Group rather than `0.0.0.0/0`?
9. What type of traffic can WAF inspect?
10. If `curl` to the ALB times out, how would you troubleshoot it layer by layer?
11. If the ALB is reachable but its target is unhealthy, which layers would you inspect?

---

## 13. Final Mental Model

```
VPC       → network boundary
 Route    → where should traffic go?
 NACL     → is subnet traffic allowed?         (stateless)
 ENI      → network interface
 SG       → is traffic allowed to/from this interface?  (stateful)
 ALB      → distributes application traffic
 WAF      → is this HTTP/HTTPS request allowed?
 EC2/App  → actually serves the request
```
