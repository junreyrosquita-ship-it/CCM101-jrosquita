# Final Reflection
## The Enterprise Cloud Architect — ROSQUITA Group

Working on The Enterprise Cloud Architect project helped our group understand how cloud infrastructure components work together. We used Ubuntu Server inside VirtualBox and Docker Compose to deploy a multi-tier application using WordPress and MySQL.

Through this project, we learned how to configure containers, connect a web application to a database through a private network, and use persistent volumes so important data remains available after container restarts. We also practiced server security by configuring UFW and checking which services and ports are exposed.

Another important lesson was automation. We created a Bash script to back up the MySQL database, verify the compressed archive, keep an activity log, and remove older backup files. We used Cron to schedule the backup so it can run automatically without manual execution.

We also learned that a working deployment requires monitoring, troubleshooting, documentation, and recovery testing—not just starting containers. Checking container status and logs helped us understand how to diagnose service problems.

Overall, this project improved our practical skills in Linux administration, containerization, networking, security, storage, and automation. It also taught us to divide responsibilities, communicate clearly, and test our work before presenting it. As the ROSQUITA Group, we gained a better understanding of how to plan, deploy, and maintain a cloud application infrastructure.
