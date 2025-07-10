# frozen_string_literal: true
module Datadog
  class Statsd
    private

    CGROUPV1BASECONTROLLER = "memory"
    HOSTCGROUPNAMESPACEINODE = 0xEFFFFFFB

    def host_cgroup_namespace?
      stat = File.stat("/proc/self/ns/cgroup") rescue nil
      return false unless stat
      stat.ino == HOSTCGROUPNAMESPACEINODE
    end

    def parse_cgroup_node_path(lines)
      res = {}
      lines.split("\n").each do |line|
        tokens = line.split(':')
        next unless tokens.length == 3

        controller = tokens[1]
        path = tokens[2]

        if controller == CGROUPV1BASECONTROLLER || controller == ''
          res[controller] = path
        end
      end

      res
    end

    def get_cgroup_inode(cgroup_mount_path, proc_self_cgroup_path)
      content = File.read(proc_self_cgroup_path) rescue nil
      return nil unless content

      controllers = parse_cgroup_node_path(content)

      [CGROUPV1BASECONTROLLER, ''].each do |controller|
        next unless controllers[controller]

        segments = [
          cgroup_mount_path.chomp('/'),
          controller.strip,
          controllers[controller].sub(/^\//, '')
        ]
        path = segments.reject(&:empty?).join("/")
        inode = inode_for_path(path)
        return inode unless inode.nil?
      end

      nil
    end

    def inode_for_path(path)
      stat = File.stat(path) rescue nil
      return nil unless stat
      "in-#{stat.ino}"
    end

    def parse_container_id(handle)
      exp_line = /^\d+:[^:]*:(.+)$/
      uuid = /[0-9a-f]{8}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{12}/
      container = /[0-9a-f]{64}/
      task = /[0-9a-f]{32}-\d+/
      exp_container_id = /(#{uuid}|#{container}|#{task})(?:\.scope)?$/

      handle.each_line do |line|
        match = line.match(exp_line)
        next unless match && match[1]
        id_match = match[1].match(exp_container_id)

        return id_match[1] if id_match && id_match[1]
      end

      nil
    end

    def read_container_id(fpath)
      handle = File.open(fpath, 'r') rescue nil
      return nil unless handle

      id = parse_container_id(handle)
      handle.close
      id
    end

    # Extracts the final container info from a line in mount info
    def extract_container_info(line)
      parts = line.strip.split("/")
      return nil unless parts.last == "hostname"

      # Expected structure: [..., <group>, <container_id>, ..., "hostname"]
      container_id = nil
      group = nil

      parts.each_with_index do |part, idx|
        # Match the container id and include the section prior to it.
        if part.length == 64 && !!(part =~ /\A[0-9a-f]{64}\z/)
          group = parts[idx - 1] if idx >= 1
          container_id = part
        elsif part.length > 32 && !!(part =~ /\A[0-9a-f]{32}-\d+\z/)
          group = parts[idx - 1] if idx >= 1
          container_id = part
        elsif !!(part =~ /\A[0-9a-f]{8}(-[0-9a-f]{4}){4}\z/)
          group = parts[idx - 1] if idx >= 1
          container_id = part
        end
      end

      return container_id unless group == "sandboxes"
    end

    # Parse /proc/self/mountinfo to extract the container id.
    # Often container runtimes embed the container id in the mount paths.
    # We parse the mount with a final `hostname` component, which is part of
    # the containers `etc/hostname` bind mount.
    def parse_mount_info(handle)
      handle.each_line do |line|
        split = line.split(" ")
        mnt1 = split[3]
        mnt2 = split[4]
        [mnt1, mnt2].each do |line|
          container_id = extract_container_info(line)
          return container_id unless container_id.nil?
        end
      end

      nil
    end

    def read_mount_info(path)
      handle = File.open(path, 'r') rescue nil
      return nil unless handle

      info = parse_mount_info(handle)
      handle.close
      info
    end

    def get_container_id(user_provided_id, cgroup_fallback)
      return user_provided_id unless user_provided_id.nil?
      return nil unless cgroup_fallback

      container_id = read_container_id("/proc/self/cgroup")
      return container_id unless container_id.nil?

      container_id = read_mount_info("/proc/self/mountinfo")
      return container_id unless container_id.nil?

      return nil if host_cgroup_namespace?

      get_cgroup_inode("/sys/fs/cgroup", "/proc/self/cgroup")
    end
  end
end
