# Web terminals

> [Introduced][ce-7690] in GitLab 8.15. Only project masters and owners can
  access web terminals.

With the introduction of the [Kubernetes project service][kubservice], GitLab
gained the ability to store and use credentials for a Kubernetes cluster. One
of the things it uses these credentials for is providing access to
[web terminals](../../ci/environments.html#web-terminals) for environments.

## How it works

A detailed overview of the architecture of web terminals and how they work
can be found in [this document](https://gitlab.com/gitlab-org/gitlab-workhorse/blob/master/doc/terminal.md).
In brief:

* GitLab relies on the user to provide their own Kubernetes credentials, and to
  appropriately label the pods they create when deploying.
* When a user navigates to the terminal page for an environment, they are served
  a JavaScript application that opens a WebSocket connection back to GitLab.
* The WebSocket is handled in [Workhorse](https://gitlab.com/gitlab-org/gitlab-workhorse),
   rather than the Rails application server.
* Workhorse queries Rails for connection details and user permissions; Rails
  queries Kubernetes for them in the background, using [Sidekiq](../troubleshooting/sidekiq.md)
* Workhorse acts as a proxy server between the user's browser and the Kubernetes
  API, passing WebSocket frames between the two.
* Workhorse regularly polls Rails, terminating the WebSocket connection if the
  user no longer has permission to access the terminal, or if the connection
  details have changed.

##  Enabling and disabling terminal support

As web terminals use WebSockets, every HTTP/HTTPS reverse proxy in front of
Workhorse needs to be configured to pass the `Connection` and `Upgrade` headers
through to the next one in the chain. If you installed Gitlab using Omnibus, or
from source, starting with GitLab 8.15, this should be done by the default
configuration, so there's no need for you to do anything.

However, if you run a [load balancer](../high_availability/load_balancer.md) in
front of GitLab, you may need to make some changes to your configuration. These
guides document the necessary steps for a selection of popular reverse proxies:

* [Apache](https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html)
* [NGINX](https://www.nginx.com/blog/websocket-nginx/)
* [HAProxy](http://blog.haproxy.com/2012/11/07/websockets-load-balancing-with-haproxy/)
* [Varnish](https://www.varnish-cache.org/docs/4.1/users-guide/vcl-example-websockets.html)

Workhorse won't let WebSocket requests through to non-WebSocket endpoints, so
it's safe to enable support for these headers globally. If you'd rather had a
narrower set of rules, you can restrict it to URLs ending with `/terminal.ws`
(although this may still have a few false positives).

If you installed from source, or have made any configuration changes to your
Omnibus installation before upgrading to 8.15, you may need to make some
changes to your configuration. See the  [8.14 to 8.15 upgrade](../../update/8.14-to-8.15.md#nginx-configuration)
document for more details.

If you'd like to disable web terminal support in GitLab, just stop passing
the `Connection` and `Upgrade` hop-by-hop headers in the *first* HTTP reverse
proxy in the chain. For most users, this will be the NGINX server bundled with
Omnibus Gitlab, in which case, you need to:

* Find the `nginx['proxy_set_headers']` section of your `gitlab.rb` file
* Ensure the whole block is uncommented, and then comment out or remove the
  `Connection` and `Upgrade` lines.

For your own load balancer, just reverse the configuration changes recommended
by the above guides.

When these headers are not passed through, Workhorse will return a
`400 Bad Request` response to users attempting to use a web terminal. In turn,
they will receive a `Connection failed` message.

## Limiting WebSocket connection time

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/8413)
in GitLab 8.17.

Terminal sessions use long-lived connections; by default, these may last
forever. You can configure a maximum session time in the Admin area of your
GitLab instance if you find this undesirable from a scalability or security
point of view.

[ce-7690]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/7690
[kubservice]: ../../user/project/integrations/kubernetes.md
