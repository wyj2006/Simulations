#include <cmath>
#include <cstdio>
#include <fstream>
#include <numbers>
#include <random>
#include <vector>

using namespace std;

double dt = 0.001;
double case_top_radius = 100;
double case_bottom_radius = 10;
double case_height = 100;
int case_top_point_num = 100;
int case_bottom_point_num = 10;
vector<int> case_point_num;
ofstream data_file;

struct Vector3 {
    double x = 0, y = 0, z = 0;
    Vector3() = default;
    Vector3(double x, double y, double z) : x(x), y(y), z(z) {}
    Vector3(const Vector3 &v) = default;
    Vector3 &operator=(const Vector3 &v) = default;
    Vector3 operator*(double a) { return Vector3(x * a, y * a, z * a); }
    Vector3 operator/(double a) { return Vector3(x / a, y / a, z / a); }
    Vector3 operator+(const Vector3 &v)
    {
        return Vector3(x + v.x, y + v.y, z + v.z);
    }
    Vector3 operator-(const Vector3 &v)
    {
        return Vector3(x - v.x, y - v.y, z - v.z);
    }
    Vector3 &operator+=(const Vector3 &v)
    {
        x += v.x;
        y += v.y;
        z += v.z;
        return *this;
    }
    Vector3 &operator-=(const Vector3 &v)
    {
        x -= v.x;
        y -= v.y;
        z -= v.z;
        return *this;
    }
    double dot(const Vector3 &v) { return x * v.x + y * v.y + z * v.z; }
    Vector3 cross(const Vector3 &v)
    {
        return Vector3(y * v.z - v.y * z, z * v.x - v.z * x, x * v.y - v.x * y);
    }
    double length() { return sqrt(x * x + y * y + z * z); }
    Vector3 normalize() { return *this / length(); }
};

Vector3 gravity{0, 0, -10};

struct Sand {
    Vector3 pos, velocity;
    Vector3 force;
    double radius = 0.1, mass = 1;
    bool disabled = false;
    Sand() = default;
    Sand(Vector3 pos) : pos(pos) {}
    Sand(Vector3 pos, bool disabled) : pos(pos), disabled(disabled) {}
    Sand(const Sand &s) = default;
    Sand &operator=(const Sand &s) = default;
    void update(int stage)
    {
        if (disabled) return;
        switch (stage)
        {
        case 1: force = gravity * mass; break;
        case 2: velocity += force / mass * dt; break;
        case 3: pos += velocity * dt; break;
        }
    }
};

struct Collision {
    Sand *a;
    Sand *b;        // 当b为nullptr说明与内壁碰撞
    Vector3 normal; // 法线(碰撞方向a->b)
    double depth;   // 嵌入深度
};

vector<Sand> sands;
vector<Collision> collisions;

void detect_collision(Sand &a, Sand &b)
{
    if (a.disabled || b.disabled) return;
    double distance = (a.pos - b.pos).length();
    if (distance > a.radius + b.radius) return;
    Collision collision{
        .a = &a,
        .b = &b,
        .normal = (b.pos - a.pos).normalize(),
        .depth = a.radius + b.radius - distance,
    };
    collisions.push_back(collision);
}

// 检测与内壁的碰撞
void detect_collision(Sand &a)
{
    if (a.disabled) return;
    if (a.pos.z < 0 || a.pos.z > case_height) return;
    if (a.pos.x == 0 && a.pos.y == 0) return;
    Vector3 parallel{
        case_top_radius - case_bottom_radius,
        case_height,
        0,
    }; // 与内壁平行的单位向量(截面)
    Vector3 pos{
        Vector3(a.pos.x, a.pos.y, 0).length() - case_bottom_radius,
        a.pos.z,
        0,
    }; // 物体在这个截面的位置向量
    double alpha = acos(parallel.normalize().dot(pos.normalize()));
    if (alpha < asin(a.radius / pos.length()))
    {
        double theta = acos(
            Vector3(a.pos.x, a.pos.y, 0).normalize().dot(Vector3(1, 0, 0)));
        Collision collision{
            .a = &a,
            .b = nullptr,
            .normal = Vector3(parallel.y * cos(theta), parallel.y * sin(theta),
                              -parallel.x)
                          .normalize(),
            .depth = a.radius - pos.length() * sin(alpha),
        };
        collisions.push_back(collision);
    }
}

void detect_collision()
{
    for (size_t i = 0; i < sands.size(); i++)
    {
        detect_collision(sands[i]);
        for (size_t j = i + 1; j < sands.size(); j++)
            detect_collision(sands[i], sands[j]);
    }
}

void update_collision()
{
    for (auto &collision : collisions)
    {
        if (collision.b != nullptr)
        {
            collision.a->pos -= collision.normal * collision.depth / 2;
            collision.b->pos += collision.normal * collision.depth / 2;
            double impluse = -1 * (1 + 1)
                             * (collision.a->velocity - collision.b->velocity)
                                   .dot(collision.normal)
                             / (1 / collision.a->mass + 1 / collision.b->mass);
            collision.a->velocity +=
                collision.normal * impluse / collision.a->mass;
            collision.b->velocity -=
                collision.normal * impluse / collision.b->mass;
        }
        else
        {
            collision.a->pos = collision.normal * collision.depth;
            double impluse = -1 * (1 + 1)
                             * (collision.a->velocity).dot(collision.normal)
                             / (1 / collision.a->mass);
            collision.a->velocity +=
                collision.normal * impluse / collision.a->mass;
        }
    }
}

int main()
{
    data_file.open(".dat", ios::out | ios::binary);
    random_device seed;
    mt19937 gen(seed());
    uniform_real_distribution<> dist_xy(-case_top_radius / 2,
                                        case_top_radius / 2);
    uniform_real_distribution<> dist_z(case_height, case_height * 2);
    for (int i = 10; i <= 100; i += 10) case_point_num.push_back(i);
    double tan_alpha = (case_top_radius - case_bottom_radius)
                       / case_height; // 与竖直平面夹角的正切值
    for (size_t i = 0; i < case_point_num.size(); i++)
    {
        double height = i * case_height / (case_point_num.size() - 1);
        double radius = case_bottom_radius + height * tan_alpha;
        for (int j = 0; j < case_point_num[i]; j++)
        {
            double theta = j * 2 * numbers::pi / case_point_num[i];
            sands.push_back(
                Sand(Vector3(radius * cos(theta), radius * sin(theta), height),
                     true));
        }
    }
    for (int i = 0; i < 10000; i++)
        sands.push_back(Sand(Vector3(dist_xy(gen), dist_xy(gen), dist_z(gen))));
    auto sand_num = sands.size();
    data_file.write((const char *)&sand_num, sizeof(sand_num));
    for (size_t frame = 0; frame < 10000; frame++)
    {
        printf("Frame %llu\n", frame);
        collisions.clear();
        detect_collision();
        update_collision();
        for (auto &sand : sands) sand.update(1);
        for (auto &sand : sands) sand.update(2);
        for (auto &sand : sands) sand.update(3);
        for (auto &sand : sands)
        {
            data_file.write((const char *)&sand.pos.x, sizeof(sand.pos.x));
            data_file.write((const char *)&sand.pos.y, sizeof(sand.pos.y));
            data_file.write((const char *)&sand.pos.z, sizeof(sand.pos.z));
        }
    }
}