
resource "aws_iam_role" "myroleforekscluster" {
  name               = "mywikieksclusterrole"
  assume_role_policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
   {
   "Effect": "Allow",
   "Principal": {
    "Service": [
        "eks.amazonaws.com",
        "ec2.amazonaws.com"] 
   },
   "Action": "sts:AssumeRole"
   }
  ]
 }
POLICY
}

resource "aws_iam_role_policy_attachment" "myclusterAmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.myroleforekscluster.name
}

resource "aws_iam_role_policy_attachment" "myAmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.myroleforekscluster.name
}

resource "aws_iam_role_policy_attachment" "myAmazonEKSCNIPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.myroleforekscluster.name
}

resource "aws_iam_role_policy_attachment" "myAmazonEKSRegistryPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.myroleforekscluster.name
}

resource "aws_iam_role_policy_attachment" "myclusterAmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.myroleforekscluster.name
}



resource "aws_security_group" "myeks_sg_cluster" {
  name   = "SG-for-myekscluster"
  vpc_id = aws_vpc.myvpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Inbound Rule
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"


  tags = {
    Name = "myvpc"
  }
}

resource "aws_subnet" "myfirstprivatesubnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.0/18"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "myfirstprivatesubnet"
  }
}

resource "aws_route_table" "myfirstprivatesubnetrt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
}

resource "aws_route_table_association" "firstsubnetassociation" {
  subnet_id      = aws_subnet.myfirstprivatesubnet.id
  route_table_id = aws_route_table.myfirstprivatesubnetrt.id
}


resource "aws_subnet" "mysecondprivatesubnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.64.0/18"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "mysecondprivatesubnet"
  }
}

resource "aws_route_table" "mysecondprivatesubnetrt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
}

resource "aws_route_table_association" "secondsubnetassociation" {
  subnet_id      = aws_subnet.mysecondprivatesubnet.id
  route_table_id = aws_route_table.mysecondprivatesubnetrt.id
}

resource "aws_subnet" "myfirstpublicsubnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.128.0/18"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "myfirstpublicsubnet"
  }
}



resource "aws_subnet" "mysecondpublicsubnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.192.0/18"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "mysecondpublicsubnet"
  }
}

resource "aws_internet_gateway" "internetgateway" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "IGforkubernetes"
  }
}

resource "aws_route_table" "internetgatewayrt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internetgateway.id
  }
}

resource "aws_route_table_association" "internetgatewayassociation" {
  subnet_id      = aws_subnet.myfirstpublicsubnet.id
  route_table_id = aws_route_table.internetgatewayrt.id
}

resource "aws_eip" "ip" {
  vpc = true
  tags = {
    Name = "elk-elasticIP"
  }
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.ip.id
  subnet_id     = aws_subnet.myfirstpublicsubnet.id

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "natrt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
}

resource "aws_route_table_association" "natgatewayassociation" {
  subnet_id      = aws_subnet.mysecondpublicsubnet.id
  route_table_id = aws_route_table.natrt.id
}

resource "aws_eks_cluster" "eks_cluster_new" {
  name     = "eksclusterdemo"
  role_arn = aws_iam_role.myroleforekscluster.arn
  version  = "1.24"
  # Configure EKS with vpc and network settings 
  vpc_config {
    security_group_ids = ["${aws_security_group.myeks_sg_cluster.id}"]
    subnet_ids         = [aws_subnet.mysecondprivatesubnet.id, aws_subnet.myfirstprivatesubnet.id]

    # Configure subnets below
    /* subnet_ids = ["subnet-00eeec8e7e62647f2", "subnet-03aa0ab3512395a9a", "subnet-025ef9d6d19a9e275"] */

  }

  depends_on = [
    "aws_iam_role_policy_attachment.myclusterAmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.myAmazonEKSServicePolicy",
  ]
}

resource "aws_eks_node_group" "node1" {
  cluster_name    = aws_eks_cluster.eks_cluster_new.name
  node_group_name = "node_demo1"
  node_role_arn   = aws_iam_role.myroleforekscluster.arn
  subnet_ids      = [aws_subnet.mysecondprivatesubnet.id, aws_subnet.myfirstprivatesubnet.id]
  ami_type        = "AL2_x86_64"
  instance_types  = ["t2.micro"]
  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    "aws_iam_role_policy_attachment.myclusterAmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.myAmazonEKSServicePolicy",
  ]
}