cmake_minimum_required(VERSION 3.16)
project(so101_local)

find_package(ament_cmake REQUIRED)

install(DIRECTORY config urdf DESTINATION share/${PROJECT_NAME})

ament_package()
