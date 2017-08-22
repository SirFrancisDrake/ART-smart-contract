pragma solidity ^0.4.11;

contract queue
{
    struct Queue {
        bytes32[] data;
        uint front;
        uint back;
    }

    function _length(Queue storage q) constant internal returns (uint) {
        return q.back - q.front;
    }

    function _capacity(Queue storage q) constant internal returns (uint) {
        return q.data.length - 1;
    }

    function _push(Queue storage q, bytes32 data) internal {
        if ((q.back + 1) % q.data.length == q.front)
            // increase the queue length to fit the input data amount
            q.data.length *= 2;
            // return;
        q.data[q.back] = data;
        q.back = (q.back + 1) % q.data.length;
    }

    function _pop(Queue storage q) internal returns (bytes32 r) {
        if (q.back == q.front)
            return;
        r = q.data[q.front];
        delete q.data[q.front];
        q.front = (q.front + 1) % q.data.length;
    }

    function _popBack(Queue storage q) internal returns (bytes32 r) {
        if (q.back == q.front)
            return;
        r = q.data[q.back];
        delete q.data[q.back];
        q.back = (q.back - 1) % q.data.length;
    }

    function _isInQueue(Queue storage q, bytes32 item) internal returns (bool) {
        for (uint i = 0; i < q.data.length; i++)
            if (q.data[i] == item) return true;
        return false;
    }

    function _delete(Queue storage q, bytes32 item) internal {
        for (uint i = 0; i < q.data.length; ++i) {
            if (q.data[i] == item) {
                for (uint j = i; j < q.data.length - 1; ++j)
                    q.data[j] = q.data[j + 1];
                q.data.length -= 1;
                return;
            }
        }
    }
}

contract Storages is queue {

    address root_admin;
    address[] admins;
    Queue public storages;
    mapping(bytes32 => Queue) public contents;

    function Storages() {
        root_admin = msg.sender;
        admins.push(root_admin);
        storages.data.length = 2; // init queue
    }

    function isMember(address[] adrs, address adr) returns (bool) {
        for (uint i = 0; i < adrs.length; ++i)
            if (adrs[i] == adr)
                return true;
        return false;
    }

    function addAdmin(address adr) {
        require(msg.sender == root_admin);
        require(!ifin(admins, adr));
        admins.push(adr);
    }

    function delAdmin(address adr) {
        require(msg.sender == root_admin);
        for (uint i = 0; i < admins.length; ++i)
            if (admins[i] == adr) {
                delete admins[i];
                return;
            }
    }

    function addStorage(bytes32 d) {
        require(ifin(admins, msg.sender));
        _push(storages, d);
    }

    function getStorage() returns (bytes32 s) {
        s = _pop(storages);
        _push(storages, s);
    }

    function deleteStorage(bytes32 s) {
        require(ifin(admins, msg.sender));
        _delete(storages, s);
    }

    function addContentToStorage(bytes32 content_id, bytes32 stor) {
        if (contents[content_id].data.length == 0) {
            // init empty queue
            contents[content_id].data.length = 2;
            _push(contents[content_id], stor);
        } else if (!_isInQueue(contents[content_id], stor))
            _push(contents[content_id], stor);
    }

    function getStorageByContent(bytes32 content_id) returns (bytes32 stor) {
        if (contents[content_id].data.length == 0) {
            // not found
            return bytes32(0);
        }
        bytes32 s = _pop(contents[content_id]);
        _push(contents[content_id], s);
        return s;
    }
}
