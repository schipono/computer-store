# Computer Store

---

## Deployed   @   [store.zschipono.com](https://store.zschipono.com)


## Dev & Deployment Notes

The Application is built to run inside a single Docker container with a sidecar Postgres Database
as it's data source. The Docker container runs an Nginx reverse-proxy to accept requests, and then passes
those to Django through Gunicorn. The Django app is configured to serve the built Frontend bundle at the root path, 
with the health check and search endpoints having separate routes. Serving the Frontend bundle is done with Django's 
template and staticfiles systems, and it uses the Whitenoise Middleware to efficiently serve them without any
additional setup in Production. Serving everything through Django reduced extra deployment steps and reduces cross-origin 
issues. Search was handled with a simple compound `icontains` filter. 

The Frontend was written in React using Create React App to bootstrap development. Since the requirements asked us
to match the style as closely as possible (and since it was in Figma already), I did not use any UI Component libraries
and styled everything by hand. Debouncing the search bar was handled with an off-the-shelf DebounceInput React component. 

Deployment to AWS was done using Terraform. The only infra manually bootstrapped was registering the domain and 
setting up the initial bucket to store Terraform state. A crude hierarchical diagram of the main Infra components would
look like this:

- VPC
    - Public Subnet
        - Internet Gateway
        - Application Load Balancer
    - Private Subnet
        - NAT Gateway
        - Fargate Cluster 
          - Fargate Service
            - Application Container Tasks
        - RDS Postgres Instance

The Public Subnet is set up with an Internet Gateway to enable ingress/egress, with the Private Subnet setup
with a NAT Gateway to allow external egress. The Application Load Balancer is set up in the Public Subnet to 
listen for HTTP/HTTPS requests, and then forward those to our Fargate Service running the Application Containers.
The Database instance was placed inside the private subnet with a restricted security group that only allows access over
the DB port. 

Since the requirements specifically requested a script to load the initial data, a Django management command
was written to do this, rather than using a data migration or fixture file. To be able to run this in Production,
the Fargate Service was configured to enable command execution to open a shell into the containers, without specifically
enabling the ability to ssh. 

## Improvements

Many of the choices made while doing this were heavily impacted by time constraints, and if this was meant to be a real 
application there are a number of things I'd like to improve upon.

#### Backend
* Search accuracy is poor, and with a larger dataset I'm sure performance is poor as well. Postgres' built in Full Text
Search also gave poor results though, even after tweaking SearchVectors and Ranking. If we wanted to stay with PG or only
use one DB, I'd investigate trigrams and phonetic search, but otherwise I'd likely make a move to Elasticsearch to power this.
* Build out Models, relationships, and associated Viewsets (Vendor Model, proper Foreign keys)
* Support and add more filtering options (price filtering)
* Create and use a real Secret Key in Production that pulls from Secrets and isn't committed to the repo. 
* Parameterize Gunicorn settings/config to make adjusting on deployment for larger instances easy.
* Setup Authentication, flesh out Django Admin
* Tests (preferably w/ Pytest)
* Type hinting 
* Tighten/pin requirement versions

#### Frontend
* Decide on a design system w/ the Designer and leverage a pre-built component library (ex. Material/Chakra) to speed
up development and keep a unified look.
* Decide whether this should be responsively designed or not and stick with it - feels like it's in an in-between 
state right now 
* Could use something like Next.js for SEO with it's server-side rendered pages.
* Use a CSS preprocessor like Less/Sass - the current CSS classes are quite redundant and can easily be cleaned up.


#### Infra
* Setup proper Terraform modules and organize
* Setup performance metric based Auto-scaling on Fargate tasks/targets
* Setup mix of Fargate/Fargate Spot for easy cost reduction
* Setup RDS PG replica, scale appropriately for expected load, verify encryption at rest, automated snapshots
* Test using ASGI vs WSGI for fronting Django
* Extract and setup one-off Fargate task for DB migrations 
* Tighten security groups and IAM role/policies - pretty broad for ease of Dev right now
* Move env vars & secrets off into AWS Secrets Manager
* Setup Cloudflare to enable better CDN distribution/serving/caching of static assets/bundles, DDOS protection/WAF, etc.
* Add logging instrumentation and application performance monitoring back/front/AWS - Datadog/Splunk
* Add error capturing & alerting backend & front - Sentry

#### Devops/CI
* Setup Gitflow-ish CI/CD pipeline, at least get a Staging env/branch in between merging PRs and Production.
* Setup Build script/pipeline - building and pushing containers is manual right now
* Setup CI checks & verify on Pull Requests being opened/pushed-to, auto-deploy on merges.
* Setup Terraform Cloud to plan/preview on PRs
* Add real documentation - Docstrings, Readme's w/ setup info/notes/gotchas in major repo areas (frontend/backend/infra) and as needed.
* Setup commit-hook based linting & formatting 
